import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/app_theme.dart';

class CustomLoadingScreen extends StatelessWidget {
  const CustomLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Subtle background texture or gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.surface,
                    AppTheme.background,
                  ],
                ),
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo / Icon
                ZoomIn(
                  duration: const Duration(seconds: 1),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 1),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.minor_crash_rounded, color: AppTheme.primary, size: 60),
                        Spin(
                          infinite: true,
                          duration: const Duration(seconds: 3),
                          child: const Icon(Icons.settings_outlined, color: AppTheme.primary, size: 100),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // App Name
                FadeInUp(
                  duration: const Duration(milliseconds: 600),
                  child: const Text(
                    "AUTONEX",
                    style: TextStyle(
                      color: AppTheme.textBody,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Tagline
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: const Text(
                    "PREMIUM GARAGE SOLUTIONS",
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
                
                // Custom Linear Loading Bar
                FadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: SizedBox(
                    width: 200,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: const LinearProgressIndicator(
                            backgroundColor: AppTheme.surfaceLighter,
                            color: AppTheme.primary,
                            minHeight: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Initializing secure connection...",
                          style: AppTheme.monoStyle(color: AppTheme.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Version info at bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: Center(
                child: Text(
                  "v2.4.0 · Mastech Terminal",
                  style: AppTheme.monoStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
