import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List _inventoryItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    final res = await ApiService().getInventory();
    if (res['status'] == 'success') {
      setState(() {
        _inventoryItems = res['data'];
        _isLoading = false;
      });
    }
  }

  Future<void> _adjustStock(int id, int adjustment) async {
    final res = await ApiService().updateStock(id, adjustment);
    if (res['status'] == 'success') {
      _fetchInventory();
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0C0C0A);
    const Color surface = Color(0xFF161614);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);
    const Color text3 = Color(0xFF5A5850);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Stock Inventory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddItemModal(context),
            icon: const Icon(Icons.add_box_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: accent))
        : _inventoryItems.isEmpty 
          ? _buildEmptyState(accent, text3)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _inventoryItems.length,
              itemBuilder: (context, index) {
                final item = _inventoryItems[index];
                return _buildInventoryCard(item, surface2, accent, text3);
              },
            ),
    );
  }

  Widget _buildEmptyState(Color accent, Color text3) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, color: text3, size: 64),
          const SizedBox(height: 16),
          const Text("No inventory items found", style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 8),
          Text("Tap the + icon to add products", style: TextStyle(color: text3, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map item, Color surface2, Color accent, Color text3) {
    int stock = item['stock'] ?? 0;
    bool isOutOfStock = stock <= 0;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            // Image Placeholder
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.02),
                borderRadius: BorderRadius.circular(12),
              ),
              child: item['image_url'] != null && item['image_url'].isNotEmpty
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(item['image_url'], fit: BoxFit.cover))
                : Icon(Icons.image_not_supported_rounded, color: text3),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(item['description'] ?? "No description", style: TextStyle(color: text3, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  if (isOutOfStock)
                    const Text("OUT OF STOCK", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5))
                  else
                    Text("$stock Units Available", style: TextStyle(color: accent.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Row(
              children: [
                _buildStockBtn(Icons.remove, () => _adjustStock(item['id'], -1), surface2, Colors.white30),
                const SizedBox(width: 8),
                _buildStockBtn(Icons.add, () => _adjustStock(item['id'], 1), accent.withOpacity(0.1), accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBtn(IconData icon, VoidCallback onTap, Color bg, Color tint) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: tint.withOpacity(0.1))),
        child: Icon(icon, color: tint, size: 18),
      ),
    );
  }

  void _showAddItemModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: "1");
    const Color surface = Color(0xFF161614);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Inventory Product", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _buildInput(nameCtrl, "Product Name"),
            const SizedBox(height: 12),
            _buildInput(descCtrl, "Description", maxLines: 2),
            const SizedBox(height: 12),
            _buildInput(stockCtrl, "Initial Stock", keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final res = await ApiService().addInventoryItem({
                    'name': nameCtrl.text,
                    'description': descCtrl.text,
                    'stock': int.tryParse(stockCtrl.text) ?? 0,
                    'imageUrl': '', // TODO: Cloudflare R2 Upload
                  });
                  if (res['status'] == 'success') {
                    Navigator.pop(context);
                    _fetchInventory();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Create Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF1E1E1B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}
