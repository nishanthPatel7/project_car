import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryOrange = Color(0xFFFF5C00);
    const darkBg = Color(0xFF0A0A0A);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 80),
              // BIG HERO LOGO BLOCK
              FadeInDown(
                child: Center(
                  child: Container(
                    width: 120, // Much bigger
                    height: 120,
                    decoration: BoxDecoration(
                      color: primaryOrange,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: primaryOrange.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.build_rounded, size: 64, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeInDown(
                delay: const Duration(milliseconds: 200),
                child: const Text(
                  "MechDesk",
                  style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold, letterSpacing: -1),
                ),
              ),
              const SizedBox(height: 12),
              FadeInDown(
                delay: const Duration(milliseconds: 400),
                child: const Text(
                  "Welcome Back!",
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 4),
              FadeInDown(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  "Login to your secure car account",
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                ),
              ),
              const Spacer(),
              
              // SOCIAL LOGIN BLOCK
              FadeInUp(
                child: Column(
                  children: [
                    Text(
                      "or continue with",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        _buildSocialBtn(
                          label: "Sign in with Google",
                          icon: Icons.login_rounded,
                          color: Colors.white,
                          onTap: () => AuthService().signInWithGoogle(),
                        ),
                        const SizedBox(height: 12),
                        _buildSocialBtn(
                          label: "Sign in with Apple",
                          icon: Icons.apple_rounded,
                          color: Colors.white,
                          onTap: () {}, 
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  "By continuing, you agree to our Terms & Privacy Policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialBtn({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
