import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'login_page.dart';
import 'user_dashboard.dart';
import 'admin_dashboard.dart';
import 'garage_owner_page.dart';
import 'loading_screen.dart';

class AppDirector extends StatelessWidget {
  const AppDirector({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If not logged in, go to Login Page
        if (!snapshot.hasData) {
          return const LoginPage();
        }

        // 2. If logged in, use API to check role and send to Dashboard
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService().getInitialState(),
          builder: (context, apiSnapshot) {
            if (apiSnapshot.connectionState == ConnectionState.waiting) {
              return const CustomLoadingScreen();
            }
            
            if (apiSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text("Mumbai Server Error: ${apiSnapshot.error}\n\nTry 'flutter clean' and restart.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              );
            }

            final role = apiSnapshot.data?['role'];
            final intended = NavigationService.intendedEntry;
            print('DEBUG: AppDirector Role: $role, Intended: $intended');
            
            // 1. If explicit 'garage' entry was requested via button
            if (intended == 'garage') {
              return const GarageOwnerPage();
            }

            // 2. If 'user' entry requested OR natural login
            if (role == 'admin' && intended != 'garage') {
              return const AdminDashboard();
            }

            // 3. Default for everyone else (including garage owners clicking 'user')
            return const UserDashboard();
          },
        );
      },
    );
  }
}

class NavigationService {
  static String? intendedEntry;
}
