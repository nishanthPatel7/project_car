import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/auth_service.dart';
import '../backend/app_theme.dart';
import 'app_director.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // DESIGN DECOR
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.03), shape: BoxShape.circle),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(32)),
                      child: const Icon(Icons.car_repair_rounded, color: AppTheme.primary, size: 64),
                    ),
                  ),
                  const SizedBox(height: 32),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        const Text("MECHDESK", style: TextStyle(color: AppTheme.textBody, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
                        Text("THE GARAGE ECOSYSTEM", style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 64),
                  
                  // LOGIN OPTIONS
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _buildLoginButton(
                      context,
                      label: "Sign in as Customer",
                      icon: Icons.person_rounded,
                      color: AppTheme.primary,
                      onTap: () {
                        NavigationService.intendedEntry = 'customer';
                        AuthService().signInWithGoogle();
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: _buildLoginButton(
                      context,
                      label: "Sign in as Garage Owner",
                      icon: Icons.storefront_rounded,
                      color: AppTheme.info,
                      onTap: () {
                        NavigationService.intendedEntry = 'garage';
                        AuthService().signInWithGoogle();
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  FadeIn(
                    delay: const Duration(milliseconds: 1000),
                    child: Text(
                      "Secure multi-role authentication active", 
                      style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, {required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 20),
            Text(label, style: const TextStyle(color: AppTheme.textBody, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 12),
          ],
        ),
      ),
    );
  }
}
