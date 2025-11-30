import 'package:flutter/material.dart';
import '../supabase_config.dart';

class PriceListPage extends StatefulWidget {
  const PriceListPage({Key? key}) : super(key: key);

  @override
  State<PriceListPage> createState() => _PriceListPageState();
}

class _PriceListPageState extends State<PriceListPage> {
  bool _loading = false;
  final List<_PriceRow> _rows = [];

  // Optional: you can later add search/filter using this
  // final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPriceList();
  }

  Future<void> _loadPriceList() async {
    setState(() => _loading = true);
    try {
      final res = await supabase
          .from('price_list')
          .select()
          .order('sort_order', ascending: true);

      _rows
        ..clear()
        ..addAll(
          (res as List).map((r) => _PriceRow.fromMap(r)),
        );

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load price list: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Color palette
    const primaryColor = Color(0xFF2563EB); // blue
    const cardColor = Colors.white;
    const backgroundTop = Color(0xFFF9FAFB);
    const backgroundBottom = Color(0xFFE5E7EB);

    final primaryTextColor = const Color(0xFF111827);
    final secondaryTextColor = Colors.grey.shade600;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Price List',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2563EB),
                Color(0xFF1D4ED8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh),
            onPressed: _loadPriceList,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: _loading
              ? const LinearProgressIndicator(
            minHeight: 3,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          )
              : const SizedBox(height: 3),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _rows.isEmpty && !_loading
              ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 12),
                Text(
                  'No price list yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Prices will appear here once they are added.',
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          )
              : Column(
            children: [
              // Top "card" with title + subtle description
              Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        offset: const Offset(0, 12),
                        blurRadius: 24,
                        spreadRadius: -12,
                        color: Colors.black.withOpacity(0.08),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.local_offer_outlined,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Updated prices',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Browse the current price list for all available services.',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // If you later want a search field, you can uncomment this:
              /*
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: primaryColor,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    */

              // List content
              Expanded(
                child: ListView.builder(
                  padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: _rows.length,
                  itemBuilder: (context, index) {
                    final row = _rows[index];

                    if (row.type == 'divider') {
                      return Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.grey.shade300,
                                      Colors.grey.shade200,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (row.type == 'header') {
                      return Padding(
                        padding: const EdgeInsets.only(
                            top: 16.0, bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 18,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius:
                                BorderRadius.circular(999),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              row.label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (row.type == 'note') {
                      return Container(
                        margin:
                        const EdgeInsets.only(bottom: 6, top: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: secondaryTextColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                row.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // type == 'item'
                    final displayPrice =
                    (row.price == null || row.price!.isEmpty)
                        ? ''
                        : (row.price!.startsWith('₱')
                        ? row.price!
                        : '₱${row.price}');

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 4),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            offset: const Offset(0, 10),
                            blurRadius: 18,
                            spreadRadius: -12,
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 0.9,
                        ),
                      ),
                      child: ListTile(
                        contentPadding:
                        const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        title: Text(
                          row.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        trailing: Text(
                          displayPrice,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: primaryColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow {
  int? id;
  String type; // header | item | note | divider
  String label;
  String? price;
  int sortOrder;

  _PriceRow({
    required this.id,
    required this.type,
    required this.label,
    required this.price,
    required this.sortOrder,
  });

  factory _PriceRow.fromMap(Map<String, dynamic> map) {
    return _PriceRow(
      id: map['id'] as int?,
      type: (map['type'] ?? 'item').toString(),
      label: (map['label'] ?? '').toString(),
      price: map['price']?.toString(),
      sortOrder: (map['sort_order'] ?? 0) as int,
    );
  }
}
