import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 👈 for RealtimeChannel
import '../supabase_config.dart';
import 'price_list_page.dart'; // 👈 price list screen

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

  final _nameController = TextEditingController();
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
            )
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
      initialTime: isPickup
          ? const TimeOfDay(hour: 9, minute: 0)
          : const TimeOfDay(hour: 17, minute: 0),
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

  Future<void> _createOrder() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final notes = _notesController.text.trim();

    if (name.isEmpty ||
        location.isEmpty ||
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

      await supabase.from('laundry_orders').insert({
        'customer_id': user.id,
        'name': name,
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

  Future<void> _logout() async {
    await supabase.auth.signOut();
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

  @override
  Widget build(BuildContext context) {
    final loadingWidget =
    _loading ? const LinearProgressIndicator(minHeight: 2) : const SizedBox.shrink();

    final primaryTextColor = Colors.grey.shade900;
    final secondaryTextColor = Colors.grey.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      // ✅ Helps move content when keyboard shows (prevents bottom overflow)
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        centerTitle: false,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.indigo.shade50,
              child: Icon(
                Icons.local_laundry_service,
                size: 20,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Laundry Orders',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt),
            tooltip: 'View Price List',
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
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: loadingWidget,
        ),
      ),

      // ✅ Entire page is one scrollable to avoid both right/bottom RenderFlex overflows
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrders,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ---- Top form + header (boxed as normal widgets) ----
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // Booking card
                        Card(
                          elevation: 2,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.add_business_outlined,
                                      color: Colors.indigo.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'New Laundry Order',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const Spacer(),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Provide the details below to schedule a pickup and delivery.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 12),

                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 10),

                                TextField(
                                  controller: _locationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Pickup Address',
                                    hintText: 'Street, building, and unit details',
                                    prefixIcon: Icon(Icons.place_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                Text(
                                  'Service Type',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _serviceTextController,
                                        decoration: const InputDecoration(
                                          labelText: 'Service Type',
                                          hintText: 'Specify or select a service',
                                          prefixIcon: Icon(Icons.cleaning_services_outlined),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (val) {
                                          setState(
                                                () => _selectedService = val.isEmpty ? null : val,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        // ✅ Prevents tight horizontal layouts from overflowing
                                        isExpanded: true,
                                        value: _services.contains(_selectedService)
                                            ? _selectedService
                                            : null,
                                        items: _services
                                            .map(
                                              (s) => DropdownMenuItem<String>(
                                            value: s,
                                            child: Text(s),
                                          ),
                                        )
                                            .toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _selectedService = val;
                                            _serviceTextController.text = val ?? '';
                                          });
                                        },
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          labelText: 'Select Service',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'Payment Method',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  isExpanded: true, // ✅ helps avoid right overflow
                                  value: _selectedPayment,
                                  items: _paymentMethods
                                      .map(
                                        (p) => DropdownMenuItem<String>(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedPayment = val),
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    prefixIcon:
                                    Icon(Icons.account_balance_wallet_outlined),
                                    labelText: 'Payment Method',
                                  ),
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    Expanded(
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.upload_rounded,
                                          color: Colors.grey.shade700,
                                        ),
                                        title: Text(
                                          _pickupDateTime == null
                                              ? 'Pickup Date and Time'
                                              : _formatDateTime(_pickupDateTime),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          'Select desired pickup schedule',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                        onTap: () => _pickDateTime(true),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          Icons.download_rounded,
                                          color: Colors.grey.shade700,
                                        ),
                                        title: Text(
                                          _deliveryDateTime == null
                                              ? 'Delivery Date and Time'
                                              : _formatDateTime(_deliveryDateTime),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        subtitle: Text(
                                          'Select desired delivery schedule',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                        onTap: () => _pickDateTime(false),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                TextField(
                                  controller: _notesController,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Additional Notes (optional)',
                                    hintText:
                                    'Provide any specific instructions or preferences',
                                    alignLabelWithHint: true,
                                    prefixIcon: Icon(Icons.note_alt_outlined),
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _loading ? null : _createOrder,
                                    icon: const Icon(Icons.local_laundry_service),
                                    label: const Text('Submit Order'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo.shade700,
                                      foregroundColor: Colors.white,
                                      padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Header for orders
                        Row(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.grey.shade800,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const Spacer(),
                            if (_orders.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_orders.length} orders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.indigo.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),

                  // ---- Orders list ----
                  if (_orders.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            const SizedBox(height: 32),
                            Text(
                              'No orders have been created yet.\nSubmit a new laundry order using the form above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                              (context, index) {
                            final order = _orders[index];
                            final rider = order['rider'] as Map<String, dynamic>?;
                            final riderName = rider?['full_name'] ?? '-';
                            final riderPhone = rider?['phone'] ?? '-';
                            final riderId = order['rider_id'] ?? '-';
                            final status = order['status']?.toString();

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 6,
                                horizontal: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: _statusBorderColor(status),
                                  width: 0.7,
                                ),
                              ),
                              elevation: 1.5,
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 8.0),
                                child: ListTile(
                                  leading: Container(
                                    height: 40,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.indigo.shade50,
                                    ),
                                    child: Icon(
                                      Icons.local_laundry_service,
                                      size: 22,
                                      color: Colors.indigo.shade700,
                                    ),
                                  ),
                                  title: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Order #${order['id']}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                color: primaryTextColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(status),
                                              borderRadius:
                                              BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              (status ?? '-')
                                                  .toUpperCase()
                                                  .replaceAll('_', ' '),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: primaryTextColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Customer: ${order['name'] ?? '-'}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding:
                                    const EdgeInsets.only(top: 8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        if (order['service'] != null)
                                          const SizedBox(height: 2),
                                        if (order['service'] != null)
                                          Text(
                                            'Service: ${order['service']}',
                                            style:
                                            const TextStyle(fontSize: 13),
                                          ),
                                        if (order['pickup_address'] != null)
                                          Text(
                                            'Pickup Address: ${order['pickup_address']}',
                                            style:
                                            const TextStyle(fontSize: 13),
                                            softWrap: true,
                                          ),
                                        if (order['delivery_address'] != null)
                                          Text(
                                            'Delivery Address: ${order['delivery_address']}',
                                            style:
                                            const TextStyle(fontSize: 13),
                                            softWrap: true,
                                          ),
                                        if (order['payment_method'] != null)
                                          Text(
                                            'Payment Method: ${order['payment_method']}',
                                            style:
                                            const TextStyle(fontSize: 13),
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pickup Schedule: ${_formatDateTime(order['pickup_at'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                        Text(
                                          'Delivery Schedule: ${_formatDateTime(order['delivery_at'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Total Amount: ₱${order['total_price'] ?? 0}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (order['rider_id'] != null) ...[
                                          const SizedBox(height: 6),
                                          const Divider(height: 16),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.delivery_dining,
                                                size: 18,
                                                color: secondaryTextColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Assigned Rider: $riderName',
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                    FontWeight.w500,
                                                  ),
                                                  overflow:
                                                  TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            'Rider ID: $riderId',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            'Rider Contact Number: $riderPhone',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
    );
  }
}
