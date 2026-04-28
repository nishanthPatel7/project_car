import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../backend/app_theme.dart';

class LegalPage extends StatelessWidget {
  final String title;
  final String content;
  const LegalPage({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(title, style: const TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: FadeInUp(
          duration: const Duration(milliseconds: 400),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.surfaceLighter, width: 0.5),
            ),
            child: Text(
              content,
              style: const TextStyle(color: AppTheme.textBody, fontSize: 14, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _confirmed = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("DELETE ACCOUNT", style: TextStyle(color: AppTheme.textBody, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textBody, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            FadeInDown(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.danger.withOpacity(0.3)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 48),
                    SizedBox(height: 16),
                    Text("This action is permanent", style: TextStyle(color: AppTheme.danger, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Text(
                      "Deleting your account will remove all your vehicles, bookings, and personal data from our servers. This cannot be undone.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textBody, fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FadeInUp(
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _confirmed,
                    onChanged: (v) => setState(() => _confirmed = v ?? false),
                    title: const Text("I understand that my data will be permanently removed.", style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    activeColor: AppTheme.danger,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_confirmed && !_isLoading) ? () {
                        setState(() => _isLoading = true);
                        // In a real app, call delete user API
                        Future.delayed(const Duration(seconds: 2), () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deletion request submitted. We will process it within 48 hours.")));
                            Navigator.pop(context);
                          }
                        });
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.danger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("DELETE MY ACCOUNT", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LegalContent {
  static const String terms = """
WELCOME TO AUTONEX
By using the AutoNex application, you agree to the following terms:

1. PLATFORM NATURE
AutoNex is a bridge between vehicle owners and independent service providers (garages). We facilitate discovery and management but do not perform mechanical services ourselves.

2. NO GUARANTEES
AutoNex provides the platform "AS IS". We do not guarantee the quality, safety, or legal compliance of services provided by third-party garages. Any disputes regarding repairs must be settled directly with the service provider.

3. LIMITATION OF LIABILITY
AutoNex, its owners, and employees shall NOT be liable for any direct, indirect, incidental, or consequential damages resulting from the use of the app or services booked through it. This includes, but is not limited to, vehicle damage, personal injury, or financial loss.

4. USER RESPONSIBILITY
You are responsible for maintaining the confidentiality of your account. You agree to provide accurate information about your vehicles and identity.

5. SAFETY DISCLAIMER
We do not provide any explicit or implicit warranties regarding the roadworthiness of vehicles serviced through our partners. Always perform your own safety checks.
""";

  static const String privacy = """
PRIVACY POLICY
Last Updated: April 2026

1. DATA COLLECTION
We collect your name, email, vehicle registration details, and approximate location to facilitate bookings and provide service updates.

2. USAGE
Your data is used solely for:
- Creating and managing bookings.
- Sending status notifications.
- Connecting you with verified garages.

3. DATA PROTECTION
We use industry-standard encryption and secure cloud storage (Firebase/Turso) to protect your information.

4. SHARING
We share your vehicle details and problem description ONLY with the specific garage you choose to book with. We do NOT sell your data to advertisers or third parties.
""";

  static const String dataPolicy = """
DATA HANDLING POLICY
AutoNex is committed to transparent data management.

1. STORAGE
Your data is stored securely using Google Firebase and encrypted SQL databases.

2. RETENTION
We retain your booking history to provide you with a service log. You may request data deletion at any time via the "Delete Account" section.

3. SECURITY
Access to your data is restricted to authorized personnel and the specific service providers you interact with. We implement strict authentication protocols to prevent unauthorized access.
""";
}
