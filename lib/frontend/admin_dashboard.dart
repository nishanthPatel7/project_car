import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/auth_service.dart';
import '../backend/app_theme.dart';
import '../backend/api_service.dart';
import 'inventory_page.dart';
import 'admin_garage_requests_page.dart';
import 'notifications_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _fetchFreshData();
  }

  void _fetchFreshData() {
    setState(() {
      _dashboardFuture = ApiService().getInitialState();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _dashboardFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return _buildSkeletonDashboard();
        }

        final stats = snapshot.data?['data']?['stats'] ?? {'active_garages': 0};
        final activeGarages = stats['active_garages']?.toString() ?? '0';

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FadeInLeft(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("ADMIN TERMINAL", style: TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -1)),
                            Text("ECOSYSTEM STATUS: ONLINE", style: AppTheme.monoStyle(color: AppTheme.success, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      FadeInRight(
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _buildGlassButton(
                                  icon: Icons.notifications_none_rounded,
                                  onTap: () async {
                                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsPage(module: 'admin')));
                                    _fetchFreshData();
                                  },
                                ),
                                if ((snapshot.data?['data']?['unreadNotifications_admin'] ?? 0) > 0)
                                  Positioned(
                                    top: -4, right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                      child: Text(
                                        ((snapshot.data?['data']?['unreadNotifications_admin'] ?? 0) > 9) ? "9+" : (snapshot.data?['data']?['unreadNotifications_admin'] ?? 0).toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            _buildGlassButton(
                              icon: Icons.logout,
                              onTap: () async {
                                await AuthService().signOut();
                                // AuthWrapper in main.dart handles navigation automatically
                                // via authStateChanges() — no manual push needed.
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Expanded(child: _buildStatCard("Platform Revenue", "\$ 124,500", Icons.payments, AppTheme.info)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildStatCard("Active Garages", "$activeGarages Units", Icons.store_rounded, AppTheme.warning)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInventoryNavCard(context),
                  const SizedBox(height: 16),
                  _buildPartnerRequestsCard(context),
                  const SizedBox(height: 32),
                  Text("CENTRAL CONTROL", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: FadeInUp(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppTheme.surfaceLighter),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), shape: BoxShape.circle),
                                child: const Icon(Icons.shield_outlined, color: AppTheme.primary, size: 40),
                              ),
                              const SizedBox(height: 16),
                              const Text("Security Protocol Active", style: TextStyle(color: AppTheme.textBody, fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text("No anomalies detected in the network", style: const TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      }
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
                  Container(width: 180, height: 28, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(4))),
                  Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.surfaceLighter, borderRadius: BorderRadius.circular(12))),
                ],
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(child: Container(height: 120, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(24)))),
                  const SizedBox(width: 16),
                  Expanded(child: Container(height: 120, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.5), borderRadius: BorderRadius.circular(24)))),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 80, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(24))),
              const SizedBox(height: 16),
              Container(height: 80, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.3), borderRadius: BorderRadius.circular(24))),
              const SizedBox(height: 40),
              Expanded(child: Container(width: double.infinity, decoration: BoxDecoration(color: AppTheme.surfaceLighter.withOpacity(0.1), borderRadius: BorderRadius.circular(32)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color accent) {
    return FadeInDown(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.surfaceLighter),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent.withOpacity(0.5), size: 24),
            const SizedBox(height: 16),
            Text(value, style: AppTheme.monoStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: const TextStyle(color: AppTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryNavCard(BuildContext context) {
    return _buildNavCard(
      context,
      title: "Inventory Control",
      subtitle: "Monitor and adjust system stock",
      icon: Icons.inventory_2_rounded,
      accent: AppTheme.warning,
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryPage()));
        _fetchFreshData();
      },
    );
  }

  Widget _buildPartnerRequestsCard(BuildContext context) {
    return _buildNavCard(
      context,
      title: "Partner Requests",
      subtitle: "Approve or reject garage owners",
      icon: Icons.storefront_rounded,
      accent: AppTheme.info,
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminGarageRequestsPage()));
        _fetchFreshData();
      },
    );
  }

  Widget _buildNavCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color accent, required VoidCallback onTap}) {
    return FadeInUp(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.surfaceLighter),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: accent.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLighter),
        ),
        child: Icon(icon, color: AppTheme.textBody, size: 20),
      ),
    );
  }
}
