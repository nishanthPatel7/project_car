import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/api_service.dart';
import 'user_profile_page.dart';
import 'book_service_page.dart';

class UserDashboard extends StatelessWidget {
  const UserDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom UI Colors from HTML Mock
    const Color bg = Color(0xFF0C0C0A);
    const Color surface = Color(0xFF161614);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);
    const Color text2 = Color(0xFF9A978E);
    const Color text3 = Color(0xFF5A5850);
    const Color blue = Color(0xFF3D8EF0);

    return FutureBuilder<Map<String, dynamic>>(
      future: ApiService().getInitialState(),
      builder: (context, snapshot) {
        final name = snapshot.data?['data']?['name'] ?? 'User';
        final photo = snapshot.data?['data']?['photo'] ?? '';
        final stats = snapshot.data?['data']?['stats'] ?? {'new': 0, 'in_progress': 0, 'completed': 0, 'total': 0};
        final revenue = snapshot.data?['data']?['revenue'] ?? '0';
        final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'U';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: bg, body: Center(child: CircularProgressIndicator(color: accent)));
        }

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              children: [
                // HERO SECTION
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: surface,
                    border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Good morning,", style: TextStyle(color: text3, fontSize: 12)),
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UserProfilePage())),
                            child: Container(
                              width: 42, height: 42,
                              decoration: const BoxDecoration(color: accent, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: photo.isNotEmpty 
                                ? ClipRRect(borderRadius: BorderRadius.circular(21), child: Image.network(photo))
                                : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Vehicle Section
                      _buildVehicleSection(context, snapshot.data?['data']?['vehicles'] ?? []),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Job
                        const Text("ACTIVE JOB", style: TextStyle(color: text3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface2,
                            borderRadius: BorderRadius.circular(16),
                            border: const Border(left: BorderSide(color: accent, width: 3)),
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
                                      Text("Full Service + Brake Check", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      Text("AutoFixx Garage · #JB-2841", style: TextStyle(color: text3, fontSize: 11)),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
                                    child: const Text("In Progress", style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: const LinearProgressIndicator(value: 0.62, backgroundColor: bg, color: accent, minHeight: 3),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Inspected · Working · Ready", style: TextStyle(color: text3, fontSize: 10)),
                                  Text("Tap to view", style: TextStyle(color: text3, fontSize: 10)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                        const Text("QUICK ACTIONS", style: TextStyle(color: text3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        GridView.count(
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
                            _buildActionCard("Request Pickup", "From location", Icons.local_shipping_rounded, false, () {}),
                          ],
                        ),

                        const SizedBox(height: 28),
                        // Become Owner Banner
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF0D1A2E), Color(0xFF0A1520)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: blue.withOpacity(0.3), width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Become a Garage Owner", style: TextStyle(color: blue, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text("Register your garage on AutoServ, get jobs from customers in your area.", style: TextStyle(color: text3, fontSize: 12, height: 1.4)),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(backgroundColor: blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)),
                                  child: const Text("Register My Garage →", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),
                        const Text("SERVICE HISTORY", style: TextStyle(color: text3, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 12),
                        _buildHistoryItem("Oil Change + Filter", "Mar 14, 2025 · AutoFixx", "₹1,850", Icons.opacity_rounded),
                        _buildHistoryItem("Tyre Rotation", "Jan 02, 2025 · SpeedCare", "₹650", Icons.tire_repair_rounded),
                        _buildHistoryItem("Full Wash + Polish", "Dec 18, 2024 · AutoFixx", "₹1,200", Icons.wash_rounded),
                      ],
                    ),
                  ),
                ),
                
                // Bottom Nav
                Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 20),
                  decoration: const BoxDecoration(color: surface, border: Border(top: BorderSide(color: Colors.white10, width: 0.5))),
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
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);
    const Color text3 = Color(0xFF5A5850);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10, width: 0.5)),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.directions_car_filled_rounded, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("My vehicle", style: TextStyle(color: text3, fontSize: 10, fontWeight: FontWeight.bold)),
              Text("${firstVeh['vehicle_no']} · ${firstVeh['model']}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(100)),
            child: const Text("Active", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddVehicleCard(BuildContext context) {
    const Color accent = Color(0xFFFF4F1F);
    return GestureDetector(
      onTap: () => _openAddVehicleSheet(context),
      child: Container(
        height: 60,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.3), width: 1.5, style: BorderStyle.solid), // Simplified dotted as solid for now, will refine
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: accent.withOpacity(0.5), size: 20),
            const SizedBox(width: 8),
            Text("Add Vehicle", style: TextStyle(color: accent.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  void _openAddVehicleSheet(BuildContext context) {
    final TextEditingController noController = TextEditingController();
    final TextEditingController modelController = TextEditingController();
    const Color surface = Color(0xFF161614);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color accent = Color(0xFFFF4F1F);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Add New Vehicle", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: noController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Vehicle Number (e.g. KA-01-MH-1234)",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Model (e.g. Swift, Honda City)",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (noController.text.isEmpty || modelController.text.isEmpty) return;
                  final res = await ApiService().addVehicle({
                    'vehicleNo': noController.text,
                    'model': modelController.text,
                  });
                  if (res['status'] == 'success') {
                    Navigator.pop(context);
                    // Refresh dashboard - in a real app we'd use a provider or setstate
                    // For now, we'll just show a success message
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehicle Added!")));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: accent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("Save Vehicle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String hint, IconData icon, bool isPrimary, VoidCallback onTap) {
    const Color accent = Color(0xFFFF4F1F);
    const Color surface2 = Color(0xFF1E1E1B);
    const Color text3 = Color(0xFF5A5850);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPrimary ? accent : surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isPrimary ? Colors.white : accent, size: 22),
            const Spacer(),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(hint, style: TextStyle(color: isPrimary ? Colors.white70 : text3, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(String title, String date, String amt, IconData icon) {
    const Color surface2 = Color(0xFF1E1E1B);
    const Color text3 = Color(0xFF5A5850);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10, width: 0.5)),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(date, style: const TextStyle(color: text3, fontSize: 11)),
              ],
            ),
          ),
          Text(amt, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    const Color accent = Color(0xFFFF4F1F);
    const Color text3 = Color(0xFF5A5850);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? accent : text3, size: 24),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? accent : text3, fontSize: 9, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
