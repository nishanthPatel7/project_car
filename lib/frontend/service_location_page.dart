import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';

class ServiceLocationPage extends StatefulWidget {
  final String? initialGarageUid;
  const ServiceLocationPage({super.key, this.initialGarageUid});

  @override
  State<ServiceLocationPage> createState() => _ServiceLocationPageState();
}

class _ServiceLocationPageState extends State<ServiceLocationPage> {
  List _allGarages = [];
  List _filteredGarages = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGarages();
  }

  Future<void> _fetchGarages() async {
    setState(() => _isLoading = true);
    final res = await ApiService().getApprovedGarages();
    if (mounted) {
      setState(() {
        _allGarages = res['garages'] ?? [];
        _filteredGarages = _allGarages;
        _isLoading = false;
      });

      // Auto-open if initialGarageUid is provided
      if (widget.initialGarageUid != null) {
        final match = _allGarages.firstWhere(
          (g) => (g['user_uid'] == widget.initialGarageUid || g['partner_id'] == widget.initialGarageUid),
          orElse: () => null,
        );
        if (match != null) {
          _showGarageDetails(match);
        }
      }
    }
  }

  void _filterGarages(String query) {
    setState(() {
      _filteredGarages = _allGarages.where((g) {
        final name = (g['name'] ?? g['business_name'] ?? "").toString().toLowerCase();
        final city = (g['city'] ?? "").toString().toLowerCase();
        final address = (g['address'] ?? "").toString().toLowerCase();
        return name.contains(query.toLowerCase()) || 
               city.contains(query.toLowerCase()) || 
               address.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("SERVICE LOCATIONS", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterGarages,
                style: const TextStyle(color: AppTheme.textBody, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search by garage name or city...",
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading 
              ? _buildSkeletonList()
              : _filteredGarages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _filteredGarages.length,
                    itemBuilder: (context, index) {
                      final garage = _filteredGarages[index];
                      return FadeInUp(
                        duration: Duration(milliseconds: 400 + (index * 100)),
                        child: _buildGarageCard(garage),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarageCard(Map garage) {
    final String name = garage['name'] ?? garage['business_name'] ?? "Partner Garage";
    final String city = garage['city'] ?? "Unknown City";
    final String address = garage['address'] ?? "Address not available";
    final List photos = garage['photo_urls'] as List? ?? [];
    final String image = photos.isNotEmpty ? photos[0] : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () => _showGarageDetails(garage),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGE SECTION
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: AppTheme.background,
                    child: image.isNotEmpty
                      ? Image.network(image, fit: BoxFit.cover, 
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.store_rounded, color: AppTheme.textMuted, size: 40))
                      : const Icon(Icons.store_rounded, color: AppTheme.textMuted, size: 40),
                  ),
                ],
              ),
            ),
            
            // CONTENT SECTION
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text("VERIFIED", style: TextStyle(color: AppTheme.primary, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(city, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  if (address.isNotEmpty && address != "Address not available") ...[
                    const SizedBox(height: 12),
                    Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, height: 1.4)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _showGarageDetails(garage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text("View Details", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGarageDetails(Map garage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text(garage['name'] ?? garage['business_name'] ?? "Garage Details", style: const TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (garage['location'] != null && garage['location'].toString().isNotEmpty) ...[
                _buildInfoSection("Location", garage['location'], Icons.location_on_rounded),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (garage['city'] != null) Expanded(child: _buildInfoSection("City", garage['city'], Icons.location_city_rounded)),
                  if (garage['district'] != null) ...[
                    const SizedBox(width: 12),
                    Expanded(child: _buildInfoSection("District", garage['district'], Icons.map_rounded)),
                  ],
                ],
              ),
              if (garage['state'] != null) ...[
                const SizedBox(height: 12),
                _buildInfoSection("State", garage['state'], Icons.explore_rounded),
              ],
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              _buildInfoSection("Services", "General Service, Oil Change, Brake Repair, Painting, AC Service, Battery Replacement, and more.", Icons.settings_rounded),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text("Book Appointment Now", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, height: 1.5)),
      ],
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 300,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, color: AppTheme.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text("No garages found", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
          const Text("Try a different search term", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
