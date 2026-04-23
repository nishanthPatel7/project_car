import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/auth_service.dart';
import '../backend/api_service.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF5C00);
    const darkBg = Color(0xFF0A0A0A);
    const cardBg = Color(0xFF1A1A1A);

    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getInitialState(),
        builder: (context, snapshot) {
          final name = snapshot.data?['data']?['name'] ?? 'User Profile';
          final photo = snapshot.data?['data']?['photo'] ?? '';
          
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // STARTING BLOCK (Identity)
                FadeInDown(
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryOrange, width: 2)),
                          child: CircleAvatar(
                            radius: 50,
                            backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo.isEmpty ? const Icon(Icons.person, size: 50) : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        "Garage Owner", 
                        style: TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                
                // PROFILE MENU
                _buildMenuItem(Icons.person_outline_rounded, "My Profile", cardBg),
                _buildMenuItem(Icons.lock_outline_rounded, "Change Password", cardBg),
                _buildMenuItem(Icons.notifications_none_rounded, "Notifications", cardBg),
                _buildMenuItem(Icons.help_outline_rounded, "Help & Support", cardBg),
                
                const Spacer(),
                
                // LOGOUT BUTTON (AS PER IMAGE 14)
                FadeInUp(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: primaryOrange),
                    onPressed: () => AuthService().signOut(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white))),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ],
      ),
    );
  }
}
