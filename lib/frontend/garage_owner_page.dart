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
import 'multiple_garage_setup.dart';
import 'garage_bookings_page.dart';

class GarageOwnerPage extends StatefulWidget {
  const GarageOwnerPage({super.key});

  @override
  State<GarageOwnerPage> createState() => _GarageOwnerPageState();
}

class _GarageOwnerPageState extends State<GarageOwnerPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _existingRequest;
  List<Map<String, dynamic>> _allRequests = [];
  bool _hasPendingRequest = false;
  int _approvedCount = 0;
  int _currentStep = 0; // 0: Explanation, 1: Form
  String? _selectedGarageId;
  late Future<Map<String, dynamic>> _dashboardFuture;

  // Form Controllers
  final TextEditingController _storeNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
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
    final requests = await ApiService().getAllGarageRequests();
    if (mounted) {
      setState(() {
        _allRequests = requests;
        _hasPendingRequest = requests.any((r) => r['status'] == 'pending');
        _approvedCount = requests.where((r) => r['status'] == 'approved').length;
        
        if (_approvedCount > 0) {
          final approvedGarages = requests.where((r) => r['status'] == 'approved').toList();
          // Keep current selection if valid, otherwise pick first
          if (_selectedGarageId == null || !approvedGarages.any((g) => g['partner_id'] == _selectedGarageId)) {
            _selectedGarageId = approvedGarages.first['partner_id'];
          }
          _existingRequest = approvedGarages.firstWhere((g) => g['partner_id'] == _selectedGarageId);
        } else if (requests.isNotEmpty) {
          _existingRequest = requests.first;
        } else {
          _existingRequest = null;
        }
        
        _dashboardFuture = ApiService().getInitialState(garageId: _selectedGarageId);
        _isLoading = false;
      });
    }
  }

  void _switchGarage(String partnerId) {
    setState(() {
      _selectedGarageId = partnerId;
      _existingRequest = _allRequests.firstWhere((r) => r['partner_id'] == partnerId);
      _dashboardFuture = ApiService().getInitialState(garageId: partnerId);
    });
  }

  void _refreshDashboard() {
    setState(() {
      _dashboardFuture = ApiService().getInitialState(garageId: _selectedGarageId);
    });
  }

  Future<void> _submit() async {
    if (_storeNameController.text.isEmpty || _ownerNameController.text.isEmpty || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all details")));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final res = await ApiService().submitGarageRequest({
        'name': _storeNameController.text,
        'ownerName': _ownerNameController.text,
        'phone': _phoneController.text,
        'photoUrls': [], // Simplified for now to get it running
      });
      if (res['status'] == 'success') {
        _fetchStatus();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
      return _buildDashboardView();
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

  Widget _buildDashboardView() {
    final hasApproved = _approvedCount > 0;
    final garageName = (_existingRequest!['name'] ?? "GARAGE").toString();

    if (!hasApproved) {
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
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
            return _buildSkeletonDashboard();
          }
          final data = snapshot.data?['data'];
          final stats = data?['stats'] ?? {};
          final name = data?['name'] ?? (_existingRequest!['name'] ?? "GARAGE");

          return SafeArea(
            child: Column(
              children: [
                _buildHeader(name, data?['unreadNotifications_garage'] ?? 0),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLifetimeOverview(stats),
                        const SizedBox(height: 24),
                        _buildDailyOverview(stats),
                        const SizedBox(height: 32),
                        
                        _buildSectionHeader("New Requests", (data?['newJobs'] as List?)?.length ?? 0),
                        const SizedBox(height: 16),
                        if ((data?['newJobs'] as List?)?.isEmpty ?? true)
                          _buildEmptyState("No new requests")
                        else
                          for (var job in (data?['newJobs'] as List))
                            _buildRecentJobCard(context, job, isNew: true),

                        const SizedBox(height: 32),
                        _buildSectionHeader("Ongoing Services", (data?['ongoingJobs'] as List?)?.length ?? 0),
                        const SizedBox(height: 16),
                        if ((data?['ongoingJobs'] as List?)?.isEmpty ?? true)
                          _buildEmptyState("No active services")
                        else
                          for (var job in (data?['ongoingJobs'] as List))
                            _buildRecentJobCard(context, job),
                        
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => GarageBookingsPage(garageId: _selectedGarageId))),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primary),
                            label: const Text("LEARN MORE", style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              backgroundColor: AppTheme.primary.withOpacity(0.05),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        
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

  Widget _buildHeader(String name, int unreadCount) {
    final approvedGarages = _allRequests.where((r) => r['status'] == 'approved').toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: approvedGarages.length > 1 ? () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 24),
                      const Text("SELECT GARAGE", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      ...approvedGarages.map((g) => GestureDetector(
                        onTap: () {
                          _switchGarage(g['partner_id']);
                          Navigator.pop(context);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _selectedGarageId == g['partner_id'] ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _selectedGarageId == g['partner_id'] ? AppTheme.primary : AppTheme.surfaceLighter),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.garage_rounded, color: _selectedGarageId == g['partner_id'] ? AppTheme.primary : AppTheme.textMuted),
                              const SizedBox(width: 16),
                              Expanded(child: Text(g['name'] ?? "Garage", style: TextStyle(color: AppTheme.textBody, fontWeight: _selectedGarageId == g['partner_id'] ? FontWeight.bold : FontWeight.normal))),
                              if (_selectedGarageId == g['partner_id']) const Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 16),
                            ],
                          ),
                        ),
                      )),
                    ],
                  ),
                ),
              );
            } : null,
            child: Row(
              children: [
                const Icon(Icons.menu_rounded, color: AppTheme.textBody),
                const SizedBox(width: 16),
                Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
                if (approvedGarages.length > 1) const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
              ],
            ),
          ),
          const Spacer(),
          if (_approvedCount < 3 && !_hasPendingRequest)
            IconButton(
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MultipleGaragesetup()));
                if (res == true) _fetchStatus();
              },
              icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary, size: 28),
            ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage(module: 'garage')));
              setState(() {});
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none_rounded, color: AppTheme.textBody),
                if (unreadCount > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        (unreadCount > 9) ? "9+" : unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyOverview(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today Overview", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
              Text(DateTime.now().toString().split(' ')[0], style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(stats['daily_jobs']?.toString() ?? "0", "Jobs Done"),
              _buildMiniStat("₹${stats['daily_revenue'] ?? 0}", "Revenue", isRevenue: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifetimeOverview(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primary.withOpacity(0.1), AppTheme.background]),
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: AppTheme.primary.withOpacity(0.1))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Lifetime Revenue", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("₹${stats['lifetime_revenue'] ?? 0}", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Total Jobs", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(stats['lifetime_jobs']?.toString() ?? "0", style: AppTheme.monoStyle(color: AppTheme.textBody, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String val, String label, {bool isRevenue = false}) {
    return Column(
      crossAxisAlignment: isRevenue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(val, style: AppTheme.monoStyle(color: isRevenue ? AppTheme.primary : AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildRecentJobCard(BuildContext context, Map<String, dynamic> job, {bool isNew = false}) {
    final name = job['display_name'] ?? "Unknown";
    final car = "${job['brand'] ?? 'Unknown'} ${job['vehicle_no'] ?? ''}";
    final status = job['status']?.toString().toUpperCase() ?? "PENDING";
    
    Color statusColor = AppTheme.warning;
    if (job['status'] == 'completed') statusColor = AppTheme.success;
    if (job['status'] == 'pending') statusColor = AppTheme.primary;
    if (job['status'] == 'rejected') statusColor = AppTheme.danger;

    return GestureDetector(
      onTap: () => _showDetailsModal(context, job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: isNew ? AppTheme.primary.withOpacity(0.3) : AppTheme.surfaceLighter)),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(name[0], style: const TextStyle(color: AppTheme.primary)),
            ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> job) {
    var rawServices = job['service_types'] ?? '[]';
    var decodedServices = rawServices is String ? jsonDecode(rawServices) : rawServices;
    if (decodedServices is String) {
      try {
        final nested = jsonDecode(decodedServices);
        if (nested is List) decodedServices = nested;
      } catch (e) {}
    }
    final List services = decodedServices is List ? decodedServices : [decodedServices.toString()];
    final isNew = job['status'] == 'pending';
    final isWorking = job['status'] == 'working';
    bool isTransitioning = false;

    // Parse saved cost details with resilient logic
    Map<String, dynamic> savedCosts = {};
    if (job['cost_details'] != null && job['cost_details'].toString().isNotEmpty) {
      try {
        var rawCosts = job['cost_details'];
        var decoded = rawCosts is String ? jsonDecode(rawCosts) : rawCosts;
        
        // Handle double-encoding
        if (decoded is String) {
          try {
            final nested = jsonDecode(decoded);
            if (nested is List || nested is Map) decoded = nested;
          } catch (e) {}
        }
        
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map) savedCosts[item['name'].toString()] = item['cost'];
          }
        } else if (decoded is Map) {
          savedCosts = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint("Error parsing cost_details: $e");
      }
    }

    final vehicleType = (job['vehicle_type'] ?? job['vehicleType'] ?? 'car').toString().toLowerCase();
    final vehicleIcon = vehicleType.contains('bike') ? Icons.pedal_bike_rounded : Icons.directions_car_rounded;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: isTransitioning ? 180 : MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: isTransitioning 
            ? _buildTransitionView()
            : Column(
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
                      const Text("JOB SUMMARY", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      _buildDetailRow(Icons.person_rounded, "Customer", job['display_name'] ?? "Unknown"),
                      _buildDetailRow(vehicleIcon, "Vehicle", "${job['brand'] ?? ''} ${job['vehicle_no'] ?? ''}"),
                      _buildDetailRow(Icons.access_time_rounded, "Booking Time", DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0).toString().split('.')[0].substring(0, 16)),
                      _buildDetailRow(Icons.room_service_rounded, "Mode", job['service_mode'] ?? job['serviceMode'] ?? "Walk-in"),
                      if ((job['service_mode'] ?? job['serviceMode']) == 'Pickup')
                        _buildDetailRow(Icons.location_on_rounded, "Address", job['address'] ?? "No address provided"),
                      
                      const SizedBox(height: 24),
                      const Text("REQUESTED SERVICES", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (services.isEmpty) 
                              const Text("No services recorded")
                            else 
                              for (var s in services) Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primary, size: 16),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(s.toString(), style: const TextStyle(color: AppTheme.textBody))),
                                    if (savedCosts.containsKey(s.toString()))
                                      Text("₹${savedCosts[s.toString()]}", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 13)),
                                  ],
                                ),
                              ),
                            if (job['total_amount'] != null && job['total_amount'] > 0) ...[
                              const Divider(height: 32, color: AppTheme.surfaceLighter),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("ESTIMATED TOTAL", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                                      Text(
                                        "(Includes 5% Tax: ₹${((job['total_amount'] ?? 0) * 0.05 / 1.05).toStringAsFixed(0)})", 
                                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)
                                      ),
                                    ],
                                  ),
                                  Text("₹${job['total_amount']}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 18, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      
                      if (isNew) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildActionButton("REJECT", AppTheme.danger.withOpacity(0.1), AppTheme.danger, () async {
                                await ApiService().updateJobStatus(job['id'], 'rejected');
                                Navigator.pop(context);
                                _refreshDashboard();
                              }),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildActionButton("START WORKING", AppTheme.primary, Colors.white, () async {
                                setModalState(() => isTransitioning = true);
                                await ApiService().updateJobStatus(job['id'], 'working');
                                await Future.delayed(const Duration(milliseconds: 500));
                                Navigator.pop(context);
                                _refreshDashboard();
                              }),
                            ),
                          ],
                        ),
                      ] else if (isWorking) ...[
                        _buildActionButton("MARK AS COMPLETED", AppTheme.success, Colors.white, () {
                          Navigator.pop(context);
                          _showPricingModal(context, job, services);
                        }),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransitionView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("UPDATING STATUS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: const LinearProgressIndicator(minHeight: 12, backgroundColor: AppTheme.surface, color: AppTheme.primary),
          ),
          const SizedBox(height: 12),
          const Text("Assigning mechanic...", style: TextStyle(color: AppTheme.textBody, fontSize: 14)),
        ],
      ),
    );
  }

  void _showPricingModal(BuildContext context, Map<String, dynamic> job, List services) {
    // Parse saved cost details if they exist
    // Parse saved cost details with resilient logic
    Map<String, dynamic> savedCosts = {};
    if (job['cost_details'] != null && job['cost_details'].toString().isNotEmpty) {
      try {
        var rawCosts = job['cost_details'];
        var decoded = rawCosts is String ? jsonDecode(rawCosts) : rawCosts;
        
        // Handle double-encoding
        if (decoded is String) {
          try {
            final nested = jsonDecode(decoded);
            if (nested is List || nested is Map) decoded = nested;
          } catch (e) {}
        }
        
        if (decoded is List) {
          for (var item in decoded) {
            if (item is Map) savedCosts[item['name'].toString()] = item['cost'];
          }
        } else if (decoded is Map) {
          savedCosts = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint("Error parsing cost_details in pricing modal: $e");
      }
    }

    Map<String, TextEditingController> controllers = {
      for (var s in services) 
        s.toString(): TextEditingController(text: savedCosts.containsKey(s.toString()) ? savedCosts[s.toString()].toString() : "")
    };
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("CONFIRM PRICING", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("Pre-filled from booking. Adjust only if needed.", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 32),
                ...services.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(s.toString(), style: const TextStyle(color: AppTheme.textBody))),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: controllers[s],
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}), // Refresh for live total
                          textAlign: TextAlign.right,
                          style: AppTheme.monoStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            prefixText: "₹ ",
                            filled: true, fillColor: AppTheme.surface,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(height: 48, color: AppTheme.surfaceLighter),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("FINAL BILL AMOUNT", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("(Includes 5% Tax)", style: const TextStyle(color: AppTheme.textMuted, fontSize: 8)),
                      ],
                    ),
                    Builder(
                      builder: (context) {
                        int subtotal = 0;
                        controllers.forEach((k, v) => subtotal += int.tryParse(v.text) ?? 0);
                        int finalTotal = (subtotal * 1.05).round();
                        return Text("₹$finalTotal", style: AppTheme.monoStyle(color: AppTheme.success, fontSize: 24, fontWeight: FontWeight.bold));
                      }
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 60,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : () async {
                      setModalState(() => isSubmitting = true);
                      int total = 0;
                      Map<String, int> costs = {};
                      controllers.forEach((k, v) {
                        int p = int.tryParse(v.text) ?? 0;
                        costs[k] = p;
                        total += p;
                      });

                      final res = await ApiService().updateJobStatus(job['id'], 'completed', pricing: {'totalAmount': total, 'costDetails': costs});
                      if (res['status'] == 'success') {
                        Navigator.pop(context);
                        _refreshDashboard();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRM & GENERATE BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color bg, Color text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: bg, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Text(count.toString(), style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24)),
      child: Center(child: Text(msg, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14))),
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
      decoration: BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.surfaceLighter))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.dashboard_rounded, "Dashboard", isSelected: true),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryPage())), child: _buildNavItem(Icons.inventory_2_rounded, "Inventory")),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => RecentJobsPage(module: 'garage', garageId: _selectedGarageId))), child: _buildNavItem(Icons.history_rounded, "History")),
          GestureDetector(
            onTap: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (context) => GenerateBillPage(garageId: _selectedGarageId)));
              if (res == true) _fetchStatus();
            }, 
            child: _buildNavItem(Icons.add_circle_outline_rounded, "Bills")
          ),
          GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage())), child: _buildNavItem(Icons.grid_view_rounded, "More")),
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
        FadeInDown(child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.surfaceLighter)), child: const Icon(Icons.rocket_launch_rounded, color: AppTheme.primary, size: 48))),
        const SizedBox(height: 32),
        FadeInLeft(child: const Text("Scale Your Garage\nBusiness with AutoNex", style: TextStyle(color: AppTheme.textBody, fontSize: 28, fontWeight: FontWeight.bold, height: 1.2))),
        const SizedBox(height: 24),
        FadeInLeft(delay: const Duration(milliseconds: 200), child: const Text("Join our network of elite service providers. Get discovered by thousands of car owners in your area and manage bookings seamlessly.", style: TextStyle(color: AppTheme.textMuted, fontSize: 15, height: 1.6))),
        const SizedBox(height: 48),
        FadeInUp(child: SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: () => setState(() => _currentStep = 1), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: const Text("CONTINUE TO APPLICATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))))),
      ],
    );
  }

  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("BUSINESS DETAILS", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 16),
        _buildTextField(_storeNameController, "Store Name", Icons.store_rounded),
        const SizedBox(height: 12),
        _buildTextField(_ownerNameController, "Owner Name", Icons.person_rounded),
        const SizedBox(height: 12),
        _buildTextField(_phoneController, "Phone Number", Icons.phone_rounded, keyboardType: TextInputType.phone),
        const SizedBox(height: 48),
        SizedBox(width: double.infinity, height: 60, child: ElevatedButton(onPressed: _isSubmitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT APPLICATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)))),
      ],
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
        filled: true, fillColor: AppTheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(20),
      ),
    );
  }

  Widget _buildSkeletonDashboard() {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 140, height: 20, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  Container(width: 32, height: 32, decoration: const BoxDecoration(color: AppTheme.surfaceLighter, shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(24)))),
                  const SizedBox(width: 16),
                  Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(24)))),
                ],
              ),
              const SizedBox(height: 32),
              Container(width: 120, height: 12, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    height: 120,
                    decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
