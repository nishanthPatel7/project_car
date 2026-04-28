import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../backend/app_theme.dart';
import '../backend/api_service.dart';
import 'legal_pages.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("MY PROFILE", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService().getInitialState(),
        builder: (context, snapshot) {
          final name = snapshot.data?['data']?['name'] ?? 'User';
          final email = snapshot.data?['data']?['email'] ?? '';
          final initials = name.isNotEmpty ? name.split(' ').map((e) => e[0]).take(2).join().toUpperCase() : 'U';
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // IDENTITY BLOCK
                FadeInDown(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primary.withOpacity(0.1),
                        child: Text(initials, style: const TextStyle(color: AppTheme.primary, fontSize: 32, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(color: AppTheme.textBody, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                      if (email.isNotEmpty) Text(email, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // ACCOUNT SECTION
                _buildSectionHeader("LEGAL & ACCOUNT"),
                const SizedBox(height: 12),
                _buildMenuItem(context, Icons.description_outlined, "Terms & Conditions", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "TERMS & CONDITIONS", content: LegalContent.terms)))),
                _buildMenuItem(context, Icons.privacy_tip_outlined, "Privacy Policy", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "PRIVACY POLICY", content: LegalContent.privacy)))),
                _buildMenuItem(context, Icons.security_outlined, "Data Handling Policy", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LegalPage(title: "DATA POLICY", content: LegalContent.dataPolicy)))),
                _buildMenuItem(context, Icons.delete_forever_rounded, "Delete My Account", () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DeleteAccountPage())), isDestructive: true),
                
                const SizedBox(height: 48),
                
                // LOGOUT
                FadeInUp(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text("LOG OUT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.surface,
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(color: AppTheme.danger.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
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

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isDestructive ? AppTheme.danger : AppTheme.primary, size: 22),
        title: Text(label, style: TextStyle(color: isDestructive ? AppTheme.danger : AppTheme.textBody, fontSize: 14, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
