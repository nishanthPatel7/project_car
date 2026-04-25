import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import '../backend/app_theme.dart';
import 'user_profile_page.dart';
import 'book_service_page.dart';
import 'garage_owner_page.dart';
import 'notifications_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  Key _refreshKey = UniqueKey();

  void _refreshDashboard() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: _refreshKey,
      future: ApiService().getInitialState(),
      builder: (context, snapshot) {
        final name = snapshot.data?['data']?['name'] ?? 'User';
        final photo = snapshot.data?['data']?['photo'] ?? '';
        final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'U';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppTheme.background, 
            body: Center(child: CircularProgressIndicator(color: AppTheme.primary))
          );
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
                                IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textBody, size: 24),
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage())),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage())),
                                  child: Container(
                                    width: 42, height: 42,
                                    decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                    alignment: Alignment.center,
                                    child: photo.isNotEmpty 
                                      ? ClipRRect(borderRadius: BorderRadius.circular(21), child: Image.network(photo))
                                      : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildVehicleSection(context, snapshot.data?['data']?['vehicles'] ?? []),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ACTIVE JOB
                        FadeIn(
                          delay: const Duration(milliseconds: 200),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ACTIVE JOB", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text("Full Service + Brake Check", style: TextStyle(color: AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w600)),
                                            Text("AutoFixx Garage · #JB-2841", style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                                          child: const Text("In Progress", style: TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: const LinearProgressIndicator(value: 0.62, backgroundColor: AppTheme.background, color: AppTheme.primary, minHeight: 3),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Inspected · Working · Ready", style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                                        Text("Tap to view", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 9)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
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
                              _buildActionCard("Book Service", "2 garages nearby", Icons.build_circle_rounded, true, () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const BookServicePage()));
                              }),
                              _buildActionCard("Garage Owner", "Register now", Icons.storefront_rounded, false, () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const GarageOwnerPage()));
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                        Text("SERVICE HISTORY", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        FadeInUp(
                          delay: const Duration(milliseconds: 500),
                          child: Column(
                            children: [
                              _buildHistoryItem("Oil Change + Filter", "Mar 14, 2025 · AutoFixx", "₹1,850", Icons.opacity_rounded),
                              _buildHistoryItem("Tyre Rotation", "Jan 02, 2025 · SpeedCare", "₹650", Icons.tire_repair_rounded),
                              _buildHistoryItem("Full Wash + Polish", "Dec 18, 2024 · AutoFixx", "₹1,200", Icons.wash_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // BOTTOM NAVIGATION
                Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  decoration: const BoxDecoration(color: AppTheme.surface, border: Border(top: BorderSide(color: AppTheme.surfaceLighter, width: 0.5))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_rounded, "Home", true),
                      _buildNavItem(Icons.calendar_today_rounded, "Bookings", false),
                      _buildNavItem(Icons.directions_car_rounded, "Vehicle", false),
                      _buildNavItem(Icons.person_rounded, "Profile", false),
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

    final firstVeh = vehicles[0];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.surfaceLighter)),
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
            children: [
              const Text("My vehicle", style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${firstVeh['vehicle_no']} · ${firstVeh['model']}", style: AppTheme.monoStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
            child: const Text("Active", style: TextStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? AppTheme.primary : AppTheme.textMuted, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? AppTheme.primary : AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
