import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'login_page.dart';
import 'user_dashboard.dart';
import 'admin_dashboard.dart';

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
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final role = apiSnapshot.data?['role'];
            
            if (role == 'admin') {
              return const AdminDashboard();
            } else {
              return const UserDashboard();
            }
          },
        );
      },
    );
  }
}
