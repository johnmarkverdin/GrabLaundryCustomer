import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 for RealtimeChannel
import 'package:shared_preferences/shared_preferences.dart';
import '../supabase_config.dart';
import 'auth_customer_page.dart';
import 'package:grablaundry_rider/customer/price_list_page.dart'; // 👈 ADD THIS (adjust path if needed)

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({Key? key}) : super(key: key);

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = false;

  // Realtime channel
  RealtimeChannel? _channel;

  final _nameController = TextEditingController(); // no longer shown in UI
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _serviceTextController = TextEditingController();

  String? _selectedService;
  String? _selectedPayment;
  DateTime? _pickupDateTime;
  DateTime? _deliveryDateTime;

  final List<String> _services = const [
    'Wash & Fold',
    'Dry Cleaning',
    'Ironing',
    'Premium Laundry',
  ];

  final List<String> _paymentMethods = const [
    'Cash on Delivery',
    'GCash',
  ];

  // 🎨 App-wide color helpers
  final Color _primaryColor = const Color(0xFF2563EB); // blue-ish
  final Color _surfaceColor = const Color(0xFFF3F4F6); // light gray bg
  final Color _cardColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _initRealtime();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _serviceTextController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _initRealtime() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _channel?.unsubscribe();

    _channel = supabase
        .channel('customer_orders_${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'laundry_orders',
      callback: (_) => _loadOrders(),
    )
        .subscribe();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError('Not logged in');
        return;
      }

      final res = await supabase
          .from('laundry_orders')
          .select('''
  id,
  status,
  total_price,
  service,
  payment_method,
  pickup_address,
  delivery_address,
  pickup_at,
  delivery_at,
  name,
  rider_id,
  rider:profiles!laundry_orders_rider_id_fkey (
    full_name,
    phone
  ),
  delivery_fee,
  notes
''')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      setState(() {
        _orders = (res as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      _showError('Failed to load orders: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateTime(bool isPickup) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime:
      isPickup ? const TimeOfDay(hour: 9, minute: 0) : const TimeOfDay(hour: 17, minute: 0),
    );

    if (pickedTime == null) return;

    final fullDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isPickup) {
        _pickupDateTime = fullDateTime;
      } else {
        _deliveryDateTime = fullDateTime;
      }
    });
  }

  // 🔹 Create new order (customer name from auth, not from a text field)
  Future<void> _createOrder() async {
    final location = _locationController.text.trim();
    final notes = _notesController.text.trim();

    if (location.isEmpty ||
        _selectedService == null ||
        _selectedPayment == null ||
        _pickupDateTime == null ||
        _deliveryDateTime == null) {
      _showError('Please complete all required fields.');
      return;
    }

    if (_deliveryDateTime!.isBefore(_pickupDateTime!)) {
      _showError('Delivery date and time cannot be earlier than pickup.');
      return;
    }

    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        _showError('Not logged in');
        return;
      }

      final meta = user.userMetadata ?? {};
      final customerName = (meta['full_name'] ??
          meta['name'] ??
          meta['user_name'] ??
          user.email?.split('@').first ??
          'Customer')
          .toString();

      await supabase.from('laundry_orders').insert({
        'customer_id': user.id,
        'customer_name': customerName,
        'name': customerName,
        'service': _selectedService,
        'payment_method': _selectedPayment,
        'pickup_location': location,
        'notes': notes,
        'pickup_at': _pickupDateTime!.toIso8601String(),
        'delivery_at': _deliveryDateTime!.toIso8601String(),
        'status': 'pending',
        'pickup_address': location,
        'delivery_address': location,
      });

      _nameController.clear();
      _locationController.clear();
      _notesController.clear();
      _serviceTextController.clear();

      setState(() {
        _selectedService = null;
        _selectedPayment = null;
        _pickupDateTime = null;
        _deliveryDateTime = null;
      });

      await _loadOrders();
    } catch (e) {
      _showError('Failed to create order: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔹 Edit existing order (only pending)
  Future<void> _showEditOrderDialog(Map<String, dynamic> order) async {
    final pickupCtl = TextEditingController(text: order['pickup_address'] ?? '');
    final deliveryCtl = TextEditingController(text: order['delivery_address'] ?? '');
    final notesCtl = TextEditingController(text: order['notes'] ?? '');

    String? selectedService = order['service']?.toString();
    String? selectedPayment = order['payment_method']?.toString();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Order'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pickupCtl,
                      decoration: _fieldDecoration(
                        label: 'Pickup Address',
                        icon: Icons.place_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deliveryCtl,
                      decoration: _fieldDecoration(
                        label: 'Delivery Address (optional)',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedService,
                      items: _services
                          .map(
                            (s) => DropdownMenuItem<String>(
                          value: s,
                          child: Text(s),
                        ),
                      )
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedService = val),
                      decoration: _fieldDecoration(
                        label: 'Service',
                        icon: Icons.local_laundry_service_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      value: selectedPayment,
                      items: _paymentMethods
                          .map(
                            (p) => DropdownMenuItem<String>(
                          value: p,
                          child: Text(p),
                        ),
                      )
                          .toList(),
                      onChanged: (val) => setModalState(() => selectedPayment = val),
                      decoration: _fieldDecoration(
                        label: 'Payment Method',
                        icon: Icons.account_balance_wallet_outlined,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesCtl,
                      maxLines: 3,
                      decoration: _fieldDecoration(
                        label: 'Notes',
                        hint: 'Update any special instructions',
                        icon: Icons.note_alt_outlined,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final pickup = pickupCtl.text.trim();
                    final deliveryRaw = deliveryCtl.text.trim();
                    final delivery = deliveryRaw.isEmpty ? pickup : deliveryRaw;

                    if (pickup.isEmpty) {
                      _showError('Pickup address is required.');
                      return;
                    }

                    Navigator.of(ctx).pop();

                    setState(() => _loading = true);
                    try {
                      await supabase.from('laundry_orders').update({
                        'pickup_address': pickup,
                        'delivery_address': delivery,
                        'pickup_location': pickup,
                        'notes': notesCtl.text.trim(),
                        if (selectedService != null) 'service': selectedService,
                        if (selectedPayment != null) 'payment_method': selectedPayment,
                      }).eq('id', order['id']);

                      await _loadOrders();
                    } catch (e) {
                      _showError('Failed to update order: $e');
                    } finally {
                      if (mounted) setState(() => _loading = false);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logout() async {
    setState(() => _loading = true);
    try {
      // ✅ Clear remember-me for customer
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('customer_remember_me');
      await prefs.remove('customer_email');

      await supabase.auth.signOut();

      if (!mounted) return;

      // ✅ Navigate back to auth and clear navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const CustomerAuthPage(),
        ),
            (route) => false,
      );
    } catch (e) {
      _showError('Failed to sign out: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    try {
      final dt = DateTime.parse(value.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }

  // 🎨 More neutral, professional status colors
  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.amber.shade50;
      case 'accepted':
      case 'in_progress':
        return Colors.indigo.shade50;
      case 'completed':
        return Colors.green.shade50;
      case 'cancelled':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _statusBorderColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.amber.shade300;
      case 'accepted':
      case 'in_progress':
        return Colors.indigo.shade300;
      case 'completed':
        return Colors.green.shade300;
      case 'cancelled':
        return Colors.red.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  // 🔹 Reusable modern textfield decoration
  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      alignLabelWithHint: alignLabelWithHint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: _primaryColor,
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
    );
  }

  Widget _buildOrderCard({
    required Map<String, dynamic> order,
    required String riderName,
    required String riderPhone,
    required dynamic riderId,
    required String? status,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    VoidCallback? onEdit,
  }) {
    // We keep this but we don't show it in the title anymore
    final serviceTitle =
    (order['service'] ?? 'Laundry Order').toString().trim();

    // ✅ normalize status for comparisons
    final bool isPending = status?.toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 2,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _statusBorderColor(status),
          width: 0.9,
        ),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

          // ✨ make the whole card tappable if pending
          onTap: isPending && onEdit != null ? onEdit : null,

          // ✨ LEFT ICON
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.indigo.shade50,
            ),
            child: Icon(
              Icons.local_laundry_service,
              size: 26,
              color: Colors.indigo.shade700,
            ),
          ),

          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // no service title here – empty space
                  const Expanded(child: SizedBox()),
                  const SizedBox(width: 8),

                  // STATUS CHIP
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: _statusBorderColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (status ?? '-').toUpperCase().replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: primaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),

          // SUBTITLE (NOW SHOWS ONLY ONE SERVICE LINE)
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✔️ MAIN LINE – bigger & bold
                if (order['service'] != null)
                  Text(
                    'Service: ${order['service']}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                const SizedBox(height: 4),

                if (order['pickup_address'] != null)
                  Text(
                    'Pickup: ${order['pickup_address']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    softWrap: true,
                  ),

                if (order['delivery_address'] != null)
                  Text(
                    'Delivery: ${order['delivery_address']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                    softWrap: true,
                  ),

                if (order['payment_method'] != null)
                  Text(
                    'Payment: ${order['payment_method']}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),

                // 🔹 NEW: show additional notes in history
                if (order['notes'] != null &&
                    order['notes'].toString().trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Notes: ${order['notes']}',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: secondaryTextColor,
                      ),
                      softWrap: true,
                    ),
                  ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(Icons.upload_rounded, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDateTime(order['pickup_at']),
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                Row(
                  children: [
                    const Icon(Icons.download_rounded, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _formatDateTime(order['delivery_at']),
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                Text(
                  'Total Amount: ₱${order['total_price'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                Text(
                  'Delivery Fee: ₱${order['delivery_fee'] ?? 0}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                if (order['rider_id'] != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 16),

                  Row(
                    children: [
                      Icon(
                        Icons.delivery_dining,
                        size: 20,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Rider: $riderName',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  Text(
                    'Rider ID: $riderId',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),

                  Text(
                    'Contact: $riderPhone',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryTextColor,
                    ),
                  ),
                ],

                // ✅ only show edit when pending
                if (isPending && onEdit != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Edit Order',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loadingWidget =
    _loading ? const LinearProgressIndicator(minHeight: 2) : const SizedBox.shrink();

    final primaryTextColor = Colors.grey.shade900;
    final secondaryTextColor = Colors.grey.shade600;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFC3A0), // peach
            Color(0xFFFFAFBD), // pink
            Color(0xFFE9F1FF), // soft blue finish
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: primaryTextColor,
          centerTitle: false,
          titleSpacing: 16,
          title: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade100,
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 👉 This prevents the overflow
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Laundry Orders',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Customer Portal',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 👇 ADDED THESE BUTTONS BACK
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders,
            ),
            IconButton(
              tooltip: 'Price List',
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PriceListPage(),
                  ),
                );
              },
            ),
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: loadingWidget,
          ),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadOrders,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ---- Top form + header ----
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Booking card
                          Card(
                            elevation: 3,
                            color: _cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                                bottom: Radius.circular(18),
                              ),
                              side: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header strip
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        _primaryColor,
                                        _primaryColor.withOpacity(0.85),
                                      ],
                                    ),
                                  ),
                                  padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.18),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.local_laundry_service_outlined,
                                          size: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'New Laundry Order',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            'Schedule pickup & delivery in a few steps',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Body
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 16, 16, 14),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      // 🔹 Pickup Address
                                      TextField(
                                        controller: _locationController,
                                        decoration: _fieldDecoration(
                                          label: 'Pickup Address',
                                          hint:
                                          'Street, building, and unit details',
                                          icon: Icons.place_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // 🔹 Section title
                                      Text(
                                        'Service Details',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // 🔹 Service type + dropdown
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: TextField(
                                              controller:
                                              _serviceTextController,
                                              decoration: _fieldDecoration(
                                                label: 'Service Type',
                                                hint:
                                                'Specify or select a service',
                                                icon: Icons
                                                    .local_laundry_service_outlined,
                                              ),
                                              onChanged: (val) {
                                                setState(
                                                      () => _selectedService =
                                                  val.isEmpty
                                                      ? null
                                                      : val,
                                                );
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<
                                                String>(
                                              isExpanded: true,
                                              value: _services.contains(
                                                  _selectedService)
                                                  ? _selectedService
                                                  : null,
                                              items: _services
                                                  .map(
                                                    (s) =>
                                                    DropdownMenuItem<String>(
                                                      value: s,
                                                      child: Text(s),
                                                    ),
                                              )
                                                  .toList(),
                                              onChanged: (val) {
                                                setState(() {
                                                  _selectedService = val;
                                                  _serviceTextController.text =
                                                      val ?? '';
                                                });
                                              },
                                              decoration: _fieldDecoration(
                                                label: 'Select Service',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),

                                      // 🔹 Payment & Schedule title
                                      Text(
                                        'Payment & Schedule',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // 🔹 Payment method dropdown
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: _selectedPayment,
                                        items: _paymentMethods
                                            .map(
                                              (p) =>
                                              DropdownMenuItem<String>(
                                                value: p,
                                                child: Text(p),
                                              ),
                                        )
                                            .toList(),
                                        onChanged: (val) =>
                                            setState(() => _selectedPayment = val),
                                        decoration: _fieldDecoration(
                                          label: 'Payment Method',
                                          icon: Icons
                                              .account_balance_wallet_outlined,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // 🔹 Schedule tiles
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _ScheduleTile(
                                              icon: Icons.upload_rounded,
                                              label: _pickupDateTime == null
                                                  ? 'Pickup Date & Time'
                                                  : _formatDateTime(
                                                  _pickupDateTime),
                                              subtitle:
                                              'Select desired pickup schedule',
                                              onTap: () =>
                                                  _pickDateTime(true),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _ScheduleTile(
                                              icon: Icons.download_rounded,
                                              label: _deliveryDateTime == null
                                                  ? 'Delivery Date & Time'
                                                  : _formatDateTime(
                                                  _deliveryDateTime),
                                              subtitle:
                                              'Select desired delivery schedule',
                                              onTap: () =>
                                                  _pickDateTime(false),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // 🔹 Notes
                                      TextField(
                                        controller: _notesController,
                                        maxLines: 3,
                                        decoration: _fieldDecoration(
                                          label:
                                          'Additional Notes (optional)',
                                          hint:
                                          'Provide any specific instructions or preferences',
                                          icon: Icons.note_alt_outlined,
                                          alignLabelWithHint: true,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      // 🔹 Submit button
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: _loading
                                              ? null
                                              : _createOrder,
                                          icon: const Icon(
                                            Icons.local_laundry_service,
                                          ),
                                          label:
                                          const Text('Submit Order'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                            _primaryColor,
                                            foregroundColor:
                                            Colors.white,
                                            padding: const EdgeInsets
                                                .symmetric(
                                              vertical: 13,
                                            ),
                                            shape:
                                            RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(
                                                  12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 🌈 Fancy "Order History" header
                          Container(
                            margin: const EdgeInsets.only(
                                bottom: 8, top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Color(0xFF6366F1), // indigo
                                  Color(0xFFEC4899), // pink
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.06),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding:
                                  const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Order History',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight:
                                          FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _orders.isEmpty
                                            ? 'Your completed and active orders will appear here.'
                                            : 'Review, track and manage your recent laundry orders.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white
                                              .withOpacity(0.9),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_orders.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius:
                                      BorderRadius.circular(
                                          999),
                                    ),
                                    child: Row(
                                      mainAxisSize:
                                      MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: _primaryColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_orders.length} order${_orders.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight:
                                            FontWeight.w600,
                                            color: _primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                        ]),
                      ),
                    ),

                    // ---- Orders list ----
                    if (_orders.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              const SizedBox(height: 32),
                              // colorful icon bubble
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFA5B4FC), // soft indigo
                                      Color(0xFFF9A8D4), // soft pink
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.08),
                                      blurRadius: 10,
                                      offset:
                                      const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons
                                      .local_laundry_service_rounded,
                                  size: 42,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No orders yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Create your first laundry request using the form above.\nWe\'ll keep all your orders neatly displayed here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 20),
                              // little tip card
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withOpacity(0.95),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.05),
                                      blurRadius: 8,
                                      offset:
                                      const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 18,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Tip: choose different services and add notes for special fabric care.',
                                        style:
                                        TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                                (context, index) {
                              final order = _orders[index];
                              final rider =
                              order['rider'] as Map<String, dynamic>?;
                              final riderName =
                                  rider?['full_name'] ?? '-';
                              final riderPhone =
                                  rider?['phone'] ?? '-';
                              final riderId =
                                  order['rider_id'] ?? '-';
                              final status =
                              order['status']?.toString();

                              return _buildOrderCard(
                                order: order,
                                riderName: riderName,
                                riderPhone: riderPhone,
                                riderId: riderId,
                                status: status,
                                primaryTextColor:
                                primaryTextColor,
                                secondaryTextColor:
                                secondaryTextColor,
                                // ✅ only pending orders editable (case-insensitive)
                                onEdit:
                                status?.toLowerCase() ==
                                    'pending'
                                    ? () =>
                                    _showEditOrderDialog(
                                        order)
                                    : null,
                              );
                            },
                            childCount: _orders.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _ScheduleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = Colors.grey.shade600;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD0DCFF)),
          color: const Color(0xFFF3F6FF), // light bluish tile background
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: const Color(0xFF475569),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: secondaryTextColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
