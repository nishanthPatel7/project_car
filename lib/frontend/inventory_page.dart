import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/api_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _isLoading = true;
  int _adjustmentStep = 1; // Default step
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchInventory();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _adjustmentStep = prefs.getInt('adjustment_step') ?? 1;
    });
  }

  Future<void> _saveSettings(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('adjustment_step', value);
    setState(() {
      _adjustmentStep = value;
    });
  }

  Future<void> _fetchInventory({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final res = await ApiService().getInventory();
    print("DEBUG: Inventory API Response: $res");
    
    if (res['status'] == 'success') {
      final List rawData = res['items'] ?? res['data'] ?? [];
      final List<Map<String, dynamic>> items = rawData.map((e) => Map<String, dynamic>.from(e)).toList();
      
      setState(() {
        _inventoryItems = items;
        // Re-apply filter if searching
        if (_searchController.text.isNotEmpty) {
          _filteredItems = items.where((item) {
            final name = item['name'].toString().toLowerCase();
            final desc = (item['description'] ?? "").toString().toLowerCase();
            return name.contains(_searchController.text.toLowerCase()) || desc.contains(_searchController.text.toLowerCase());
          }).toList();
        } else {
          _filteredItems = items;
        }
        _isLoading = false;
      });
    } else {
      if (!silent) setState(() => _isLoading = false);
    }
  }

  void _filterSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _inventoryItems;
      } else {
        _filteredItems = _inventoryItems.where((item) {
          final name = item['name'].toString().toLowerCase();
          final desc = (item['description'] ?? "").toString().toLowerCase();
          return name.contains(query.toLowerCase()) || desc.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteItem(int id, String? imageUrl) async {
    print("DEBUG: _deleteItem trigger for ID: $id");
    bool isDeleting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF161614),
          title: const Text("Delete Product?", style: TextStyle(color: Colors.white)),
          content: isDeleting 
            ? const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2),
                  SizedBox(height: 20),
                  Text("Removing product data...", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              )
            : const Text("This will permanently remove the item and its image.", style: TextStyle(color: Colors.white70)),
          actions: isDeleting ? [] : [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel")
            ),
            TextButton(
              onPressed: () async {
                setDialogState(() => isDeleting = true);
                
                print("DEBUG: Executing Purge in cloud for ID: $id");
                final res = await ApiService().deleteInventoryItem(id, imageUrl);
                
                if (context.mounted) {
                  Navigator.pop(context); // Close the dialog
                  
                  if (res['status'] == 'success') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Product deleted successfully"), backgroundColor: Colors.green),
                    );
                    _fetchInventory();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Delete failed: ${res['message'] ?? 'Unknown error'}"), 
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              }, 
              child: const Text("Delete", style: TextStyle(color: Colors.redAccent))
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustStock(int id, int adjustment) async {
    // Determine the raw adjustment based on bulk step (e.g., -10)
    int rawDelta = adjustment * _adjustmentStep;
    int finalAdjustmentForBackend = rawDelta;

    // 1. Optimistic UI Update with Zero-Floor Logic
    setState(() {
      final idx = _inventoryItems.indexWhere((item) => item['id'] == id);
      if (idx != -1) {
        int currentStock = _inventoryItems[idx]['stock'] ?? 0;
        int newStock = currentStock + rawDelta;
        
        if (newStock < 0) {
          newStock = 0;
          // If we are reaching the floor, the amount to send to backend 
          // is just whatever it took to get to zero.
          finalAdjustmentForBackend = -currentStock;
        }
        
        _inventoryItems[idx]['stock'] = newStock;
      }
    });

    // 2. Background Sync with the precise calculated delta
    if (finalAdjustmentForBackend == 0) return; // No change needed
    
    final res = await ApiService().updateStock(id, finalAdjustmentForBackend);
    
    // 3. If failure, rollback or re-sync
    if (res['status'] != 'success') {
      _fetchInventory(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF0C0C0A);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);
    const Color text3 = Color(0xFF5A5850);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text("Inventory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _showBulkSettingsModal,
            icon: _adjustmentStep == 1 
              ? Icon(Icons.tune_rounded, color: Colors.white.withOpacity(0.5), size: 22)
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    "${_adjustmentStep}x", 
                    style: const TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900),
                  ),
                ),
          ),
          IconButton(
            onPressed: () => _showAddItemModal(context),
            icon: const Icon(Icons.add_box_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Dynamic Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSearch,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Search products...",
                  hintStyle: TextStyle(color: text3, fontSize: 13),
                  prefixIcon: Icon(Icons.search_rounded, color: text3, size: 18),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: text3, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          _filterSearch("");
                        },
                      )
                    : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchInventory(silent: true),
              color: accent,
              backgroundColor: surface2,
              displacement: 20,
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: accent))
                : _filteredItems.isEmpty 
                  ? Stack(
                      children: [
                        ListView(), // Empty scrollable to trigger RefreshIndicator
                        _buildEmptyState(accent, text3),
                      ],
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        return _buildInventoryCard(item, surface2, accent, text3);
                      },
                    ),
            ),
          ),
        ],
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
          const Text("Empty Inventory", style: TextStyle(color: Colors.white70, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map item, Color surface2, Color accent, Color text3) {
    int stock = item['stock'] ?? 0;
    bool isOutOfStock = stock <= 0;

    return FadeIn(
      child: Container(
        decoration: BoxDecoration(
          color: surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (YouTube 16:9 Aspect Ratio)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                   ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.white.withOpacity(0.05),
                        child: item['image_url'] != null && item['image_url'].isNotEmpty
                          ? Image.network(item['image_url'], fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.image, color: text3))
                          : Icon(Icons.shopping_bag_outlined, color: text3),
                      ),
                    ),
                  Positioned(
                    top: 6, right: 6,
                    child: IconButton(
                      onPressed: () => _deleteItem(item['id'], item['image_url']),
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(backgroundColor: Colors.black45, padding: EdgeInsets.zero, minimumSize: const Size(32, 32)),
                    ),
                  ),
                  if (isOutOfStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 8)],
                            ),
                            child: const Text("NO STOCK", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            // Name & Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'], 
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    item['description'] ?? "", 
                    style: TextStyle(color: text3, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Compact Stock Counter (No bottom space)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () => _adjustStock(item['id'], -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.remove, color: Colors.white54, size: 14),
                      ),
                    ),
                    Text(
                      "$stock", 
                      style: TextStyle(color: isOutOfStock ? Colors.redAccent : accent, fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                    GestureDetector(
                      onTap: () => _adjustStock(item['id'], 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Icon(Icons.add, color: accent, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkSettingsModal() {
    int tempValue = _adjustmentStep;
    const Color surface = Color(0xFF0C0C0A);
    const Color accent = Color(0xFFFF4F1F);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text("Adjustment Step", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Change how much stock is added/removed per click", style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 32),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStepOption(1, tempValue, (val) => setModalState(() => tempValue = val)),
                  _buildStepOption(5, tempValue, (val) => setModalState(() => tempValue = val)),
                  _buildStepOption(10, tempValue, (val) => setModalState(() => tempValue = val)),
                  _buildStepOption(50, tempValue, (val) => setModalState(() => tempValue = val)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Custom input
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Custom (1-100)",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onChanged: (val) {
                  final v = int.tryParse(val);
                  if (v != null && v >= 1 && v <= 100) {
                    setModalState(() => tempValue = v);
                  }
                },
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    _saveSettings(tempValue);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Save Preference", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepOption(int val, int current, Function(int) onSelect) {
    bool isSelected = val == current;
    return GestureDetector(
      onTap: () => onSelect(val),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF4F1F) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text("$val", style: TextStyle(color: isSelected ? Colors.white : Colors.white60, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showAddItemModal(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: "1");
    const Color surface = Color(0xFF0C0C0A);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);
    const Color text3 = Color(0xFF5A5850);
    XFile? selectedImage;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      isScrollControlled: true,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          padding: EdgeInsets.fromLTRB(28, 16, 28, MediaQuery.of(context).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Handle
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text("Add New Product", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 8),
              const Text("Fill in the details to expand your inventory", style: TextStyle(color: Colors.white38, fontSize: 13)),
              const SizedBox(height: 32),
              
              // Premium Circle Image Picker
              GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (image != null) {
                    setModalState(() => selectedImage = image);
                  }
                },
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: selectedImage != null ? accent : Colors.white10, width: 1.5),
                        boxShadow: selectedImage != null ? [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 20, spreadRadius: -5)] : null,
                      ),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: surface2,
                        backgroundImage: selectedImage != null ? FileImage(File(selectedImage!.path)) : null,
                        child: selectedImage == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, color: text3, size: 32),
                                const SizedBox(height: 4),
                                const Text("IMG", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ) 
                          : null,
                      ),
                    ),
                    Positioned(
                      bottom: 4, right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                        child: Icon(selectedImage != null ? Icons.edit_rounded : Icons.add_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              _buildInput(nameCtrl, "Product Name", Icons.shopping_bag_outlined),
              const SizedBox(height: 16),
              _buildInput(descCtrl, "Description", Icons.description_outlined, maxLines: 2),
              const SizedBox(height: 16),
              _buildInput(stockCtrl, "Initial Stock", Icons.inventory_2_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 32),
              
              // Premium Action Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (nameCtrl.text.isEmpty) return;
                    
                    setModalState(() => isUploading = true);
                    String finalImageUrl = '';

                    try {
                      if (selectedImage != null) {
                        final bytes = await selectedImage!.readAsBytes();
                        final base64String = base64Encode(bytes);
                        final uploadRes = await ApiService().uploadInventoryImageProxy(
                          selectedImage!.name, 'image/jpeg', base64String
                        );
                        
                        if (uploadRes['status'] == 'success') {
                          finalImageUrl = uploadRes['publicUrl'];
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload Error: ${uploadRes['message']}"), backgroundColor: Colors.red));
                          }
                          setModalState(() => isUploading = false);
                          return;
                        }
                      }

                      final res = await ApiService().addInventoryItem({
                        'name': nameCtrl.text,
                        'description': descCtrl.text,
                        'stock': int.tryParse(stockCtrl.text) ?? 0,
                        'imageUrl': finalImageUrl,
                      });

                      if (res['status'] == 'success') {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inventory updated successfully"), backgroundColor: Colors.green));
                          Navigator.pop(context);
                        }
                        _fetchInventory();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: ${res['message']}"), backgroundColor: Colors.redAccent));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Unexpected error: $e"), backgroundColor: Colors.redAccent));
                    } finally {
                      setModalState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent, 
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: accent.withOpacity(0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isUploading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Confirm & Add Product", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white12, size: 20),
        filled: true,
        fillColor: const Color(0xFF1E1E1B),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.05))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF4F1F))),
      ),
    );
  }
}
