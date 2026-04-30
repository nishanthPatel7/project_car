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
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _allGarages = [];
  List<dynamic> _filteredGarages = [];
  bool _isLoading = true;

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
      if (widget.initialGarageUid != null) {
        final g = _allGarages.firstWhere((g) => g['partner_id'] == widget.initialGarageUid || g['user_uid'] == widget.initialGarageUid, orElse: () => null);
        if (g != null) _showGarageDetails(g);
      }
    }
  }

  void _filterGarages(String query) {
    setState(() {
      _filteredGarages = _allGarages.where((g) {
        final name = (g['name'] ?? "").toString().toLowerCase();
        final city = (g['city'] ?? "").toString().toLowerCase();
        return name.contains(query.toLowerCase()) || city.contains(query.toLowerCase());
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
        title: Text("EXPLORE GARAGES", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 10),
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
                  contentPadding: const EdgeInsets.all(15),
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
    final String name = garage['name'] ?? "Garage";
    final String city = garage['city'] ?? "Unknown City";
    final String address = garage['location'] ?? "Address not available";
    final List photos = garage['photo_urls'] ?? [];
    final String image = photos.isNotEmpty ? photos[0] : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // IMAGE SECTION
            SizedBox(
              height: 160,
              width: double.infinity,
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
                        padding: const EdgeInsets.only(left: 10, right: 10, top: 4, bottom: 4),
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
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
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
    final String gId = garage['partner_id'] ?? garage['user_uid'] ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.6,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => _GarageDetailContent(
            garage: garage, 
            garageId: gId, 
            scrollController: scrollController
          ),
        ),
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
}

class _GarageDetailContent extends StatefulWidget {
  final Map garage;
  final String garageId;
  final ScrollController scrollController;
  const _GarageDetailContent({required this.garage, required this.garageId, required this.scrollController});

  @override
  State<_GarageDetailContent> createState() => _GarageDetailContentState();
}

class _GarageDetailContentState extends State<_GarageDetailContent> {
  String _selectedCategory = 'Car';
  String? _selectedModel;
  bool _isLoadingPricing = false;
  List _availableServices = [];
  List<String> _models = [];

  @override
  void initState() {
    super.initState();
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    setState(() => _isLoadingPricing = true);
    final res = await ApiService().getGaragePricing({
      'garageUid': widget.garageId,
      'vehicleType': _selectedCategory,
    });
    
    if (mounted) {
      final List services = res['services'] ?? [];
      final uniqueModels = services.map((s) => s['model_name'].toString()).toSet().toList();
      
      setState(() {
        _availableServices = services;
        _models = uniqueModels;
        if (_models.isNotEmpty) _selectedModel = _models[0];
        _isLoadingPricing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _availableServices.where((s) => s['model_name'] == _selectedModel).toList();

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.garage['name'] ?? "Garage Details", style: const TextStyle(color: AppTheme.textBody, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${widget.garage['city']}, ${widget.garage['district']}", style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // E-SERVICES SECTION HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("E-SERVICES & OFFERS", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  _buildTypeChip("Car", Icons.directions_car_rounded),
                  const SizedBox(width: 8),
                  _buildTypeChip("Bike", Icons.pedal_bike_rounded),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // MODEL SELECTOR
          if (_models.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _models.length,
                itemBuilder: (context, index) {
                  bool isSelected = _selectedModel == _models[index];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedModel = _models[index]),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.only(left: 16, right: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLighter),
                      ),
                      alignment: Alignment.center,
                      child: Text(_models[index], style: TextStyle(color: isSelected ? Colors.white : AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),

          // SERVICES LIST
          if (_isLoadingPricing)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppTheme.primary)))
          else if (filtered.isEmpty)
            _buildEmptyPricing()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (context, index) => _buildServiceOfferCard(filtered[index]),
            ),

          const SizedBox(height: 32),
          const Divider(color: AppTheme.surfaceLighter),
          const SizedBox(height: 24),

          // ACTIONS
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text("BOOK NOW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, IconData icon) {
    bool isSelected = _selectedCategory == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = type;
          _selectedModel = null;
          _fetchPricing();
        });
      },
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.surfaceLighter),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 14),
            const SizedBox(width: 4),
            Text(type, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceOfferCard(Map s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.surfaceLighter),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.star_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s['service_name'].toString().toUpperCase(), style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                const Text("Professional Service", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("EST. COST", style: TextStyle(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
              Text("₹${s['cost']}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPricing() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.textMuted.withOpacity(0.3), size: 40),
          const SizedBox(height: 16),
          const Text("No specific offers found for this model.", textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        ],
      ),
    );
  }
}
