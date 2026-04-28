import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import '../backend/pdf_helper.dart';
import 'user_profile_page.dart';
import 'book_service_page.dart';
import 'garage_owner_page.dart';
import 'notifications_page.dart';
import 'bookings_page.dart';
import 'recent_jobs_page.dart';
import 'service_location_page.dart';
import 'legal_pages.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  Key _refreshKey = UniqueKey();
  late PageController _vehiclePageController;
  Timer? _carouselTimer;
  int _currentVehiclePage = 0;
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _vehiclePageController = PageController();
    _dashboardFuture = _loadInitialStateWithCache();
  }

  Future<Map<String, dynamic>> _loadInitialStateWithCache() async {
    // 1. Try to get from cache first
    final cached = await ApiService().getCachedInitialState();
    if (cached != null) {
      // Background fetch to update cache and UI later
      _fetchFreshData();
      return cached;
    }
    // 2. No cache, fetch from network
    return await ApiService().getInitialState();
  }

  void _fetchFreshData() async {
    final fresh = await ApiService().getInitialState();
    if (mounted) {
      setState(() {
        _dashboardFuture = Future.value(fresh);
        // Reset timer for fresh data
        _carouselTimer?.cancel();
        _carouselTimer = null;
      });
    }
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _vehiclePageController.dispose();
    super.dispose();
  }

  void _startCarouselTimer(int count) {
    _carouselTimer?.cancel();
    if (count <= 1) return;
    _carouselTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_vehiclePageController.hasClients) {
        setState(() {
          _currentVehiclePage = (_currentVehiclePage + 1) % count;
        });
        _vehiclePageController.animateToPage(
          _currentVehiclePage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _refreshDashboard() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    _fetchFreshData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: _refreshKey,
      future: _dashboardFuture,
      builder: (context, snapshot) {
        final name = snapshot.data?['data']?['name'] ?? 'User';
        final photo = snapshot.data?['data']?['photo'] ?? '';
        final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'U';

        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return _buildSkeletonDashboard();
        }

        // Handle timer start after data is loaded
        final vehicles = snapshot.data?['data']?['vehicles'] as List? ?? [];
        if (snapshot.connectionState == ConnectionState.done && _carouselTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _startCarouselTimer(vehicles.length));
        }

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Column(
              children: [
                // HERO SECTION
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: AppTheme.surface,
                      border: Border(bottom: BorderSide(color: AppTheme.surfaceLighter, width: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Good morning,", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                                Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                              ],
                            ),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationsPage(module: 'user')));
                                    _refreshDashboard();
                                  },
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      const Icon(Icons.notifications_none_rounded, color: AppTheme.textBody, size: 24),
                                      if ((snapshot.data?['data']?['unreadNotifications_user'] ?? 0) > 0)
                                        Positioned(
                                          top: -4, right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                            child: Text(
                                              ((snapshot.data?['data']?['unreadNotifications_user'] ?? 0) > 9) ? "9+" : (snapshot.data?['data']?['unreadNotifications_user'] ?? 0).toString(),
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
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildVehicleSection(context, snapshot.data?['data']?['vehicles'] ?? []),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Text("QUICK ACTIONS", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        FadeInUp(
                          delay: const Duration(milliseconds: 300),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.4,
                            children: [
                              _buildActionCard("Book Service", "2 garages nearby", Icons.build_circle_rounded, true, () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (context) => const BookServicePage()));
                                _refreshDashboard();
                              }),
                              _buildActionCard("Service Locations", "Pan India Presence", Icons.location_on_rounded, false, () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceLocationPage()));
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                        Text("MY BOOKINGS", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _buildActiveJobsSection(() {
                          final List raw = snapshot.data?['data']?['activeJobs'] ?? [];
                          final seen = <dynamic>{};
                          return raw.where((j) => seen.add(j['id'])).toList();
                        }()),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.surfaceLighter, width: 0.5))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_rounded, "Home", true, () {}),
                      _buildNavItem(Icons.calendar_today_rounded, "Bookings", false, () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingsPage()));
                        _refreshDashboard();
                      }),
                      _buildNavItem(null, "Profile", false, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage())), 
                        customIcon: Container(
                          width: 24, height: 24,
                          decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: photo.isNotEmpty 
                            ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(photo))
                            : Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleSection(BuildContext context, List vehicles) {
    if (vehicles.isEmpty) {
      return _buildAddVehicleCard(context);
    }

    return Container(
      height: 70,
      child: Stack(
        children: [
          PageView.builder(
            controller: _vehiclePageController,
            onPageChanged: (idx) => _currentVehiclePage = idx,
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final v = vehicles[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.background, 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(color: AppTheme.surfaceLighter)
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.directions_car_filled_rounded, color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("My vehicle", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        Text("${v['vehicle_no']} · ${v['model']}", style: AppTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(width: 40), // Space for dots
                  ],
                ),
              );
            },
          ),
          
          // Indicator Dots
          Positioned(
            right: 15,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(vehicles.length, (index) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 4,
                    height: _currentVehiclePage == index ? 12 : 4,
                    decoration: BoxDecoration(
                      color: _currentVehiclePage == index ? AppTheme.primary : AppTheme.textMuted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleCard(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAddVehicleSheet(context),
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5), 
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppTheme.primary.withOpacity(0.5), size: 20),
            const SizedBox(width: 8),
            Text("Add Vehicle", style: TextStyle(color: AppTheme.primary.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _openAddVehicleSheet(BuildContext context) {
    final TextEditingController noController = TextEditingController();
    final TextEditingController modelController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(alignment: Alignment.center, child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
              const Text("Add New Vehicle", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextField(
                controller: noController,
                style: const TextStyle(color: AppTheme.textBody),
                decoration: InputDecoration(
                  hintText: "Vehicle Number (e.g. KA-01-MH-1234)",
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelController,
                style: const TextStyle(color: AppTheme.textBody),
                decoration: InputDecoration(
                  hintText: "Model (e.g. Swift, Honda City)",
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (noController.text.isEmpty || modelController.text.isEmpty) return;
                    setModalState(() => isSaving = true);
                    final res = await ApiService().addVehicle({'vehicleNo': noController.text, 'model': modelController.text});
                    if (res['status'] == 'success') {
                      if (mounted) {
                        Navigator.pop(context);
                        _refreshDashboard();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehicle Added!"), backgroundColor: AppTheme.success));
                      }
                    } else {
                      setModalState(() => isSaving = false);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${res['message']}"), backgroundColor: AppTheme.danger));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: isSaving 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Save Vehicle", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String hint, IconData icon, bool isPrimary, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : AppTheme.primary, size: 22),
            const Spacer(),
            Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(hint, style: TextStyle(color: isPrimary ? Colors.white70 : AppTheme.textMuted, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String date, String amt, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.surfaceLighter, width: 0.5)),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: AppTheme.background.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: AppTheme.textMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(date, style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Text(amt, style: AppTheme.monoStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData? icon, String label, bool isActive, VoidCallback onTap, {Widget? customIcon}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ?? Icon(icon, color: isActive ? AppTheme.primary : AppTheme.textMuted, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: isActive ? AppTheme.primary : AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobsSection(List jobs) {
    if (jobs.isEmpty) return const SizedBox.shrink();
    
    // Limit to latest 3 for dashboard
    final displayJobs = jobs.take(3).toList();
    final hasMore = jobs.length > 3;

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayJobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _buildActiveJobCard(displayJobs[index]),
          ),
          
          if (hasMore) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BookingsPage())),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primary),
                label: Text("Load More (${jobs.length - 3})", style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  backgroundColor: AppTheme.primary.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(Map job) {
    final status = job['status'] ?? 'pending';
    double progress = 0.33;
    String statusLabel = "Booking Received";
    String footer = "Waiting for Garage";
    
    if (status == 'working' || status == 'in_progress') {
      progress = 0.66;
      statusLabel = "Working";
      footer = "Mechanic is servicing vehicle";
    } else if (status == 'completed') {
      progress = 1.0;
      statusLabel = "Ready";
      footer = "Work Finished";
    }

    final date = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0);
    final dateStr = DateFormat('dd/MM/yyyy').format(date);

    return GestureDetector(
      onTap: () => _showBookingDetails(context, job),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: status == 'working' ? AppTheme.warning : AppTheme.primary, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['vehicle_no'] ?? job['vehicleNo'] ?? "Vehicle", 
                        style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w600)
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceLocationPage(initialGarageUid: job['garage_uid']))),
                        child: Text(
                          "${job['garage_name'] ?? job['garageName'] ?? job['garage'] ?? job['partner_name'] ?? job['partnerName'] ?? 'Partnered Garage'} · #${job['id']}", 
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, decoration: TextDecoration.underline, decorationColor: AppTheme.textMuted)
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (status == 'working' ? AppTheme.warning : AppTheme.primary).withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(100)
                  ),
                  child: Text(
                    statusLabel.toUpperCase(), 
                    style: TextStyle(color: status == 'working' ? AppTheme.warning : AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress, 
                backgroundColor: AppTheme.background, 
                color: status == 'working' ? AppTheme.warning : AppTheme.primary, 
                minHeight: 4
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(footer, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                Row(
                  children: [
                    Text(dateStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
                    const SizedBox(width: 8),
                    Text(status == 'pending' ? "Step 1/3" : (status == 'working' ? "Step 2/3" : "Step 3/3"), style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 9)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Map job) {
    final status = job['status'] ?? 'pending';
    final date = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0);
    final dateStr = DateFormat('dd MMM yyyy · hh:mm a').format(date);
    
    Color statusColor = AppTheme.primary;
    if (status == 'working' || status == 'in_progress') statusColor = AppTheme.warning;
    if (status == 'completed') statusColor = AppTheme.success;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Booking Details", style: const TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("ID: #${job['id'] ?? job['invoice_no'] ?? 'N/A'}", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(status.toString().toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(child: _buildCompactDetail("VEHICLE", job['vehicle_no'] ?? job['vehicleNo'] ?? "N/A", Icons.directions_car_filled_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCompactDetail("GARAGE", job['garage_name'] ?? job['garageName'] ?? job['garage'] ?? "Partner Garage", Icons.store_rounded,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ServiceLocationPage(initialGarageUid: job['garage_uid']))))),
                ],
              ),
              if ((job['problem_desc'] ?? job['problemDesc']) != null && (job['problem_desc'] ?? job['problemDesc']).toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildCompactDetail("ISSUE", job['problem_desc'] ?? job['problemDesc'], Icons.report_problem_rounded),
              ],
              
              const SizedBox(height: 24),
              const Divider(color: AppTheme.surfaceLighter),
              const SizedBox(height: 24),
              
              Text("SERVICES", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 16),
              if ((job['service_types'] ?? job['serviceTypes']) != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (() {
                    var services = job['service_types'] ?? job['serviceTypes'];
                    if (services is String && services.startsWith('[') && services.endsWith(']')) {
                      try { services = jsonDecode(services); } catch (e) {}
                    }
                    if (services is List) {
                      return services.map((s) => _buildServiceChip(s.toString())).toList();
                    } else if (services is String) {
                      return [_buildServiceChip(services)];
                    }
                    return <Widget>[];
                  })(),
                )
              else
                _buildServiceChip("General Service"),
              
              if (status == 'completed' && (job['total_amount'] ?? job['totalAmount']) != null) ...[
                const SizedBox(height: 24),
                const Divider(color: AppTheme.surfaceLighter),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL PAID", style: TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("₹${job['total_amount'] ?? job['totalAmount']}", style: AppTheme.monoStyle(color: AppTheme.primary, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => PdfHelper.generateJobInvoice(Map<String, dynamic>.from(job)),
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                    label: const Text("DOWNLOAD INVOICE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactDetail(String label, String value, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface, 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: onTap != null ? AppTheme.primary.withOpacity(0.3) : AppTheme.surfaceLighter)
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text(value, 
                    style: TextStyle(
                      color: AppTheme.textBody, 
                      fontSize: 12, 
                      fontWeight: FontWeight.bold,
                      decoration: onTap != null ? TextDecoration.underline : null,
                    ), 
                    overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.success.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 14),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(color: AppTheme.textBody, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.surfaceLighter)),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(List history) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No history yet", style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
      );
    }
    return Column(
      children: history.map((job) {
        final date = DateTime.fromMillisecondsSinceEpoch(job['created_at'] ?? 0);
        final dateStr = "${date.day}/${date.month}/${date.year}";
        return _buildHistoryItem(
          job['vehicle_no'] ?? "Service", 
          "$dateStr · ${job['garage_name'] ?? 'Garage'}", 
          "₹${job['total_amount'] ?? 0}", 
          Icons.history_rounded
        );
      }).toList(),
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
                  Container(width: 150, height: 24, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  Container(width: 44, height: 44, decoration: const BoxDecoration(color: AppTheme.surfaceLighter, shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(height: 32),
              Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(24))),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(20)))),
                  const SizedBox(width: 12),
                  Expanded(child: Container(height: 100, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(20)))),
                ],
              ),
              const SizedBox(height: 32),
              Container(width: 120, height: 12, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    height: 80,
                    decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text("ACCOUNT & LEGAL", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 16),
            _buildProfileItem(Icons.description_outlined, "Terms & Conditions", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "TERMS & CONDITIONS", content: LegalContent.terms)))),
            _buildProfileItem(Icons.privacy_tip_outlined, "Privacy Policy", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "PRIVACY POLICY", content: LegalContent.privacy)))),
            _buildProfileItem(Icons.security_outlined, "Data Policy", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "DATA POLICY", content: LegalContent.dataPolicy)))),
            _buildProfileItem(Icons.delete_forever_outlined, "Delete Account", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteAccountPage())), isDestructive: true),
            const Divider(color: AppTheme.surfaceLighter, height: 32),
            _buildProfileItem(Icons.logout_rounded, "Logout", () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            }, isDestructive: true),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: isDestructive ? AppTheme.danger : AppTheme.primary, size: 22),
      title: Text(title, style: TextStyle(color: isDestructive ? AppTheme.danger : AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
