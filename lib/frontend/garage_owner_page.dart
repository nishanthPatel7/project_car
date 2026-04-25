import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import '../backend/pdf_helper.dart';
import 'inventory_page.dart';
import 'user_profile_page.dart';
import 'notifications_page.dart';
import 'recent_jobs_page.dart';
import 'generate_bill_page.dart';

class GarageOwnerPage extends StatefulWidget {
  const GarageOwnerPage({super.key});

  @override
  State<GarageOwnerPage> createState() => _GarageOwnerPageState();
}

class _GarageOwnerPageState extends State<GarageOwnerPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _existingRequest;
  int _currentStep = 0; // 0: Explanation, 1: Form

  // Form Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  List<XFile> _storePhotos = [];
  bool _isSubmitting = false;
  bool _isFetchingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    final res = await ApiService().getGarageRequestStatus();
    if (mounted) {
      setState(() {
        _existingRequest = res['request'] != null ? Map<String, dynamic>.from(res['request'] as Map) : null;
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
    if (_nameController.text.isEmpty || _phoneController.text.isEmpty || _aadhaarController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all details")));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Photo Upload Failed: ${res['message']}"), backgroundColor: AppTheme.danger));
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final res = await ApiService().submitGarageRequest({
        'name': _nameController.text,
        'phone': _phoneController.text,
        'aadhaar': _aadhaarController.text,
        'city': _cityController.text,
        'district': _districtController.text,
        'state': _stateController.text,
        'location': _locationController.text,
        'photoUrls': photoUrls,
      });

      if (res['status'] == 'success') {
        _fetchStatus();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Application Submitted!"), backgroundColor: AppTheme.success));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message'] ?? 'Unknown error'}"), backgroundColor: AppTheme.danger));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System Error: ${e.toString()}"), backgroundColor: AppTheme.danger));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppTheme.background, body: Center(child: CircularProgressIndicator(color: AppTheme.primary)));
    }

    if (_existingRequest != null) {
      return _buildStatusView();
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("BECOME A PARTNER", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _currentStep == 0 ? _buildExplanationView() : _buildFormView(),
      ),
    );
  }

  Widget _buildStatusView() {
    final status = _existingRequest!['status'];
    final isApproved = status == 'approved';
    final garageName = (_existingRequest!['name'] ?? "GARAGE").toString();

    if (!isApproved) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.av_timer_rounded, color: AppTheme.primary, size: 64),
              const SizedBox(height: 24),
              const Text("UNDER REVIEW", style: TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text("Our team is verifying $garageName. This takes ~24h.", textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getInitialState(),
        builder: (context, snapshot) {
          final data = snapshot.data?['data'];
          final stats = data?['stats'] ?? {};
          final recentJobs = data?['recentJobs'] ?? [];
          final name = data?['name'] ?? (_existingRequest!['name'] ?? "GARAGE");

          return SafeArea(
            child: Column(
              children: [
                // --- HEADER ---
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      const Icon(Icons.menu_rounded, color: AppTheme.textBody),
                      const SizedBox(width: 16),
                      Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
                        child: const Icon(Icons.notifications_none_rounded, color: AppTheme.textBody),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- TODAY OVERVIEW ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Today Overview", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(DateTime.now().toString().split(' ')[0], style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniStat(stats['completed']?.toString() ?? "0", "Completed"),
                                  _buildMiniStat(stats['in_progress']?.toString() ?? "0", "In Progress"),
                                  _buildMiniStat(stats['new']?.toString() ?? "0", "New Jobs"),
                                  _buildMiniStat("₹${stats['revenue'] ?? 0}", "Revenue", isRevenue: true),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        const Text("Job Status", style: TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        
                        // --- JOB STATUS CHART BOX ---
                        Row(
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 120, height: 120,
                                  child: CircularProgressIndicator(
                                    value: (stats['total'] ?? 0) > 0 ? (stats['completed'] ?? 0) / (stats['total'] ?? 1) : 0, 
                                    strokeWidth: 12, 
                                    backgroundColor: Colors.white.withOpacity(0.05), 
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary)
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(stats['total']?.toString() ?? "0", style: const TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
                                    Text("Total Jobs", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 8)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 40),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildLegendItem(AppTheme.success, "New", stats['new']?.toString() ?? "0"),
                                  _buildLegendItem(AppTheme.warning, "In Progress", stats['in_progress']?.toString() ?? "0"),
                                  _buildLegendItem(AppTheme.textMuted, "Completed", stats['completed']?.toString() ?? "0"),
                                  _buildLegendItem(AppTheme.danger, "Cancelled", "0"),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Recent Jobs", style: TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RecentJobsPage())),
                              child: Text("View All", style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (recentJobs.isEmpty)
                          Center(child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24.0),
                            child: Text("No jobs assigned yet", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)),
                          ))
                        else
                          for (var job in recentJobs)
                            _buildRecentJobCard(context, job),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildMiniStat(String val, String label, {bool isRevenue = false}) {
    return Column(
      crossAxisAlignment: isRevenue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(val, style: AppTheme.monoStyle(color: isRevenue ? AppTheme.primary : AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const Spacer(),
          Text(count, style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecentJobCard(BuildContext context, Map<String, dynamic> job) {
    final name = job['display_name'] ?? "Unknown";
    final car = "${job['brand'] ?? 'Unknown'} ${job['vehicle_no'] ?? ''}";
    final status = job['status']?.toString().toUpperCase() ?? "PENDING";
    final statusColor = job['status'] == 'completed' ? AppTheme.success : AppTheme.warning;
    final amount = job['total_amount'];

    return GestureDetector(
      onTap: () => _showDetailsModal(context, job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.surfaceLighter)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.1), child: Text(name[0], style: const TextStyle(color: AppTheme.primary))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(car, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (amount != null && amount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("₹$amount", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.3))),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> job) {
    // Shared modal logic across the app
    final Map<String, dynamic> costs = jsonDecode(job['cost_details'] ?? '{}');
    final List<dynamic> services = jsonDecode(job['service_types'] ?? '[]');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("JOB SUMMARY", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                            if (job['invoice_no'] != null)
                              Text("#${job['invoice_no']}", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildDetailSection("Customer Details", [
                      _buildDetailRow(Icons.person_rounded, "Name", job['display_name'] ?? "Unknown"),
                      _buildDetailRow(Icons.directions_car_rounded, "Vehicle", "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}"),
                      _buildDetailRow(Icons.calendar_today_rounded, "Date", DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split(' ')[0]),
                    ]),
                    const SizedBox(height: 24),
                    const Text("ITEMIZED SERVICES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
                      child: Column(
                        children: [
                          if (services.isEmpty) 
                            const Text("No services recorded", style: TextStyle(color: AppTheme.textMuted))
                          else
                            ...services.map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(s.toString(), style: const TextStyle(color: AppTheme.textBody, fontWeight: FontWeight.w500)),
                                  Text("₹${costs[s] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 14)),
                                ],
                              ),
                            )),
                          const Divider(color: AppTheme.surfaceLighter, height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("TOTAL AMOUNT", style: TextStyle(color: AppTheme.textBody, fontWeight: FontWeight.bold)),
                              Text("₹${job['total_amount'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (job['problem'] != null && job['problem'].toString().isNotEmpty) ...[
                      const Text("ADDITIONAL NOTES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 12),
                      Text(job['problem'], style: const TextStyle(color: AppTheme.textBody, height: 1.5)),
                    ],
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: () => PdfHelper.generateJobInvoice(job),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text("DOWNLOAD PDF", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceLighter)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.dashboard_rounded, "Dashboard", isSelected: true),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryPage())),
            child: _buildNavItem(Icons.inventory_2_rounded, "Inventory")
          ),
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const GenerateBillPage()));
              if (result == true) {
                // Refresh data if a bill was generated
                setState(() {}); // Re-trigger FutureBuilder
              }
            },
            child: _buildNavItem(Icons.add_circle_outline_rounded, "Bills"),
          ),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage())),
            child: _buildNavItem(Icons.grid_view_rounded, "More")
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, {bool isSelected = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isSelected ? AppTheme.primary : AppTheme.textMuted, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isSelected ? AppTheme.primary : AppTheme.textMuted, fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildExplanationView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeInDown(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
            child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primary, size: 48),
          ),
        ),
        const SizedBox(height: 32),
        FadeInLeft(
          child: const Text("Scale Your Garage\nBusiness with MechDesk", style: TextStyle(color: AppTheme.textBody, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
        ),
        const SizedBox(height: 24),
        FadeInLeft(
          delay: const Duration(milliseconds: 200),
          child: const Text(
            "Join our network of elite service providers. Get discovered by thousands of car owners in your area and manage bookings seamlessly.",
            style: TextStyle(color: AppTheme.textMuted, fontSize: 15, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        _buildBenefitItem(Icons.trending_up_rounded, "Global Visibility", "Reach customers who are actively looking for services nearby."),
        _buildBenefitItem(Icons.inventory_2_rounded, "Inventory Manager", "Premium tools to manage your stock, pricing, and spare parts."),
        _buildBenefitItem(Icons.payments_rounded, "Instant Payouts", "Get paid directly and track your revenue in real-time."),
        const SizedBox(height: 48),
        FadeInUp(
          child: SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: () => setState(() => _currentStep = 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary, 
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("CONTINUE TO APPLICATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("BUSINESS DETAILS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _buildTextField(_nameController, "Owner Name", Icons.person_rounded),
        const SizedBox(height: 12),
        _buildTextField(_phoneController, "Phone Number", Icons.phone_rounded, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        _buildTextField(_aadhaarController, "Aadhaar Card Number", Icons.credit_card_rounded),
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
            ),
            child: _isSubmitting 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text("SUBMIT APPLICATION", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppTheme.textBody, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppTheme.textMuted, fontSize: 14),
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
