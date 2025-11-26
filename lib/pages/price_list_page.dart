import 'package:flutter/material.dart';

class PriceListPage extends StatelessWidget {
  const PriceListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> items = [
      // Regular Clothes
      {"header": "Regular Clothes (Wash – Dry – Fold)"},
      {"name": "3 kg", "price": "70"},
      {"name": "5 kg", "price": "110"},
      {"name": "7 kg", "price": "150"},
      {"name": "8 kg", "price": "170"},
      {"name": "10 kg", "price": "200"},
      {"name": "12 kg", "price": "230"},
      {"name": "15 kg", "price": "280"},
      {"note": "Extra detergent or fabric conditioner: +₱10 per load"},

      // Bedding
      {"header": "Bedding / Comforters / Blankets"},
      {"name": "Pillowcase / Bedsheet", "price": "60"},
      {"name": "Blanket (thin)", "price": "70"},
      {"name": "Comforter (medium)", "price": "90"},
      {"name": "Comforter (thick)", "price": "110"},
      {"name": "Mattress Cover", "price": "120"},

      // Drop-off Load
      {"header": "Drop-Off Load (Fixed Rate)"},
      {"name": "Small Load (~5 kg)", "price": "120"},
      {"name": "Medium Load (~8 kg)", "price": "170"},
      {"name": "Large Load (~10 kg)", "price": "200"},
      {"note": "Add ₱30 for heavy items such as jeans or towels"},

      // Ironing
      {"header": "Ironing / Pressing Service"},
      {"name": "T-Shirt / Polo", "price": "30"},
      {"name": "Pants / Jeans", "price": "40"},
      {"name": "Dress", "price": "50"},
      {"name": "Jacket / Blazer", "price": "60"},
      {"name": "Bedsheet / Blanket", "price": "70"},

      // Dry Cleaning
      {"header": "Dry Cleaning (per piece)"},
      {"name": "Suit (Top)", "price": "500"},
      {"name": "Barong Tagalog", "price": "400"},
      {"name": "Jacket / Coat", "price": "350"},
      {"name": "Wedding Gown", "price": "3000"},
      {"name": "Gown (Regular)", "price": "1000"},

      // Express
      {"header": "Express Service (Within 8 Hours)"},
      {"note": "Add ₱100 per load for same-day processing"},

      // Add-ons
      {"header": "Additional Services / Add-Ons"},
      {"name": "Fabric Conditioner (Premium)", "price": "10"},
      {"name": "Stain Removal Treatment", "price": "20"},
      {"name": "Plastic Packaging", "price": "5"},
      {"name": "Softening & Iron Combo", "price": "30"},
      {"name": "Folding Only Service", "price": "40"},

      // Delivery
      {"header": "Pick-Up and Delivery Service"},
      {"name": "Within 1 km radius", "price": "₱0 (Free)"},
      {"name": "1 – 3 km", "price": "50"},
      {"name": "4 – 5 km", "price": "80"},
      {"name": "6 km and above", "price": "100 – 150"},
      {"note": "FREE delivery for laundry worth ₱500 and above"},

      // Promos
      {"header": "Free Services and Promotions"},
      {"note": "• Free hanger for ironed clothes"},
      {"note": "• Free eco bag for new customers"},
      {"note": "• Free delivery on your 5th transaction"},
      {"note": "• Loyalty card: Get 1 free kilo after 10 loads"},

      {"divider": true},
      {
        "note":
        "Notes:\n• Minimum weight: 3 kg\n• Standard turn-around time: 24–48 hours\n• Operating hours: 8:00 AM – 5:00 PM daily"
      },
    ];

    final primaryTextColor = Colors.grey.shade900;
    final secondaryTextColor = Colors.grey.shade600;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: primaryTextColor,
        centerTitle: false,
        title: const Text(
          'Service Price Guide',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          // Top intro card
          if (i == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_laundry_service_outlined,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laundry Service Pricing',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Below is an overview of our standard service rates for washing, ironing, dry cleaning, and delivery.',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final item = items[i - 1];

          // SECTION HEADER
          if (item.containsKey("header")) {
            return Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item["header"],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // DIVIDER
          if (item.containsKey("divider")) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(
                thickness: 1,
                height: 1,
                color: Colors.grey.shade300,
              ),
            );
          }

          // NOTE / INFO
          if (item.containsKey("note")) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.02),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.indigo.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item["note"],
                      style: TextStyle(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // PRICE ROW
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item["name"],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    item["price"].toString().startsWith('₱')
                        ? item["price"]
                        : "₱${item["price"]}",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
