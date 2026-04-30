import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import 'garage_services_page.dart';

class MultipleGaragesetup extends StatefulWidget {
  const MultipleGaragesetup({super.key});

  @override
  State<MultipleGaragesetup> createState() => _MultipleGaragesetupState();
}

class _MultipleGaragesetupState extends State<MultipleGaragesetup> {
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  List<Map<String, dynamic>> _existingRequests = [];
  bool _isLoading = true;
  bool _showForm = false;
  List<XFile> _storePhotos = [];
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final res = await ApiService().getAllGarageRequests();
    if (mounted) {
      setState(() {
        _existingRequests = res;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    if (_storePhotos.length >= 2) return;
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image != null) {
      setState(() {
        _storePhotos.add(image);
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Location services are disabled.';

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permission denied';
      }
      
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _cityController.text = place.locality ?? "";
          _districtController.text = place.subLocality ?? "";
          _stateController.text = place.administrativeArea ?? "";
          _locationController.text = "${position.latitude}, ${position.longitude}";
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    } finally {
      setState(() => _isFetchingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (_storeNameController.text.isEmpty || 
        _ownerNameController.text.isEmpty || 
        _phoneController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _districtController.text.isEmpty ||
        _stateController.text.isEmpty ||
        _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All fields are mandatory"), backgroundColor: AppTheme.danger));
      return;
    }
    if (_storePhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least 1 store photo")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<String> photoUrls = [];
      for (var file in _storePhotos) {
        final bytes = await file.readAsBytes();
        final base64String = base64Encode(bytes);
        final res = await ApiService().uploadInventoryImageProxy(file.name, 'image/jpeg', base64String);
        
        if (res['status'] == 'success') {
          photoUrls.add(res['publicUrl']);
        } else {
          throw "Photo Upload Failed: ${res['message']}";
        }
      }

      final res = await ApiService().submitGarageRequest({
        'name': _storeNameController.text,
        'ownerName': _ownerNameController.text,
        'phone': _phoneController.text,
        'city': _cityController.text,
        'district': _districtController.text,
        'state': _stateController.text,
        'location': _locationController.text,
        'photoUrls': photoUrls,
      });

      if (res['status'] == 'success') {
        if (mounted) {
          _showForm = false;
          _loadExisting();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!"), backgroundColor: AppTheme.success));
        }
      } else {
        throw res['message'] ?? 'Unknown error';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => _showForm ? setState(() => _showForm = false) : Navigator.pop(context),
        ),
        title: Text(_showForm ? "NEW GARAGE REQUEST" : "YOUR GARAGE DETAILS", style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showForm) ...[
              const Text("LISTED GARAGES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 16),
              if (_existingRequests.isEmpty)
                _buildEmptyState()
              else
                ..._existingRequests.map((req) => _buildGarageCard(req)),
              
              const SizedBox(height: 32),
              
              if (_existingRequests.length < 3 && !_existingRequests.any((r) => r['status'] == 'pending'))
                GestureDetector(
                  onTap: () => setState(() => _showForm = true),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 24),
                        const SizedBox(width: 12),
                        const Text("REQUEST NEW GARAGE", style: TextStyle(color: AppTheme.primary, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                )
              else if (_existingRequests.any((r) => r['status'] == 'pending'))
                _buildInfoBanner("You have a request pending review. Please wait for approval before adding another.")
              else if (_existingRequests.length >= 3)
                _buildInfoBanner("Maximum limit of 3 garages reached."),
            ],

            if (_showForm) ...[
              FadeInUp(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BUSINESS DETAILS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    _buildTextField(_storeNameController, "Store Name", Icons.store_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(_ownerNameController, "Owner Name", Icons.person_rounded),
                    const SizedBox(height: 12),
                    _buildTextField(_phoneController, "Phone Number", Icons.phone_rounded, keyboardType: TextInputType.phone),
                    const SizedBox(height: 28),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("LOCATION INFO", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        TextButton.icon(
                          onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                          icon: _isFetchingLocation 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                            : const Icon(Icons.my_location_rounded, size: 14, color: AppTheme.primary),
                          label: const Text("Auto Fetch", style: TextStyle(color: AppTheme.primary, fontSize: 10)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(_cityController, "City", Icons.location_city_rounded),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(_districtController, "District", Icons.map_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildTextField(_stateController, "State", Icons.public_rounded)),
                      ],
                    ),
                    const SizedBox(height: 28),

                    const Text("STORE PHOTOS (1-2)", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (var i = 0; i < 2; i++)
                          Expanded(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                height: 100,
                                margin: EdgeInsets.only(right: i == 0 ? 12 : 0),
                                decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.surfaceLighter)),
                                child: _storePhotos.length > i
                                  ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_storePhotos[i].path), fit: BoxFit.cover))
                                  : const Icon(Icons.add_a_photo_rounded, color: AppTheme.textMuted),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 48),

                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary, 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SUBMIT APPLICATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
      child: Column(
        children: [
          Icon(Icons.garage_rounded, color: AppTheme.textMuted.withOpacity(0.2), size: 64),
          const SizedBox(height: 16),
          const Text("No Garages Linked", style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.primary.withOpacity(0.1))),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildGarageCard(Map<String, dynamic> req) {
    final status = req['status'] ?? 'pending';
    final name = req['name'] ?? 'Garage';
    final city = req['city'] ?? 'Unknown';
    
    Color statusColor = AppTheme.warning;
    if (status == 'approved') statusColor = AppTheme.success;
    if (status == 'rejected') statusColor = AppTheme.danger;

    return GestureDetector(
      onTap: () => _showReadOnlyDetails(req),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          borderRadius: BorderRadius.circular(20), 
          border: Border.all(color: AppTheme.surfaceLighter)
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(status == 'approved' ? Icons.check_circle_rounded : Icons.pending_rounded, color: statusColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(city, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReadOnlyDetails(Map<String, dynamic> req) {
    final status = (req['status'] ?? 'pending').toString().toUpperCase();
    Color statusColor = AppTheme.warning;
    if (status == 'APPROVED') statusColor = AppTheme.success;
    if (status == 'REJECTED') statusColor = AppTheme.danger;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            
            // Header with Compact Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("GARAGE DETAILS", style: TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (status == 'APPROVED')
                    TextButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GarageServicesPage(garageId: req['partner_id'] ?? '', garageName: req['name'] ?? 'Garage'))),
                      icon: const Icon(Icons.settings_rounded, size: 16),
                      label: const Text("MANAGE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        backgroundColor: AppTheme.primary.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(Icons.store_rounded, "Business Name", req['name'] ?? "N/A"),
                    _buildInfoRow(Icons.person_rounded, "Owner Name", req['owner_name'] ?? "N/A"),
                    _buildInfoRow(Icons.phone_rounded, "Phone Number", req['phone'] ?? "N/A"),
                    _buildInfoRow(Icons.location_city_rounded, "City", req['city'] ?? "N/A"),
                    _buildInfoRow(Icons.map_rounded, "District/State", "${req['district'] ?? ''}, ${req['state'] ?? ''}"),
                    _buildInfoRow(Icons.my_location_rounded, "Coordinates", req['location'] ?? "N/A"),
                    
                    const SizedBox(height: 16),
                    const Text("SUBMITTED PHOTOS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    if (req['photo_urls'] != null)
                      SizedBox(
                        height: 180,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: (req['photo_urls'] is String ? jsonDecode(req['photo_urls']) as List : req['photo_urls'] as List).map<Widget>((url) => Container(
                            width: 260,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface, 
                              borderRadius: BorderRadius.circular(20), 
                              image: DecorationImage(image: NetworkImage(url.toString()), fit: BoxFit.cover),
                              border: Border.all(color: AppTheme.surfaceLighter),
                            ),
                          )).toList(),
                        ),
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // STICKY BOTTOM BUTTON
            if (status == 'APPROVED')
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, -10))],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GarageServicesPage(garageId: req['partner_id'] ?? '', garageName: req['name'] ?? 'Garage'))),
                      icon: const Icon(Icons.settings_suggest_rounded),
                      label: const Text("MANAGE SERVICES & PRICING", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: AppTheme.textBody, fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: AppTheme.textBody, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: AppTheme.primary, size: 18),
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.surfaceLighter)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.primary)),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }
}
