import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'login_page.dart';
import 'user_dashboard.dart';
import 'admin_dashboard.dart';
import 'garage_owner_page.dart';
import 'loading_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class AppDirector extends StatefulWidget {
  const AppDirector({super.key});

  @override
  State<AppDirector> createState() => _AppDirectorState();
}

class _AppDirectorState extends State<AppDirector> {
  String? _persistedRole;
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedRole();
  }

  Future<void> _loadPersistedRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _persistedRole = prefs.getString('intended_role');
        _isInit = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const CustomLoadingScreen();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoginPage();

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
                    child: Text("Server Error: ${apiSnapshot.error}", textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  ),
                ),
              );
            }

            final role = apiSnapshot.data?['role'];
            final intended = NavigationService.intendedEntry ?? _persistedRole;
            
            if (intended == 'garage') return const GarageOwnerPage();
            if (role == 'admin' && intended != 'garage') return const AdminDashboard();
            return const UserDashboard();
          },
        );
      },
    );
  }
}

class NavigationService {
  static String? _intendedEntry;
  static String? get intendedEntry => _intendedEntry;
  
  static set intendedEntry(String? role) {
    _intendedEntry = role;
    SharedPreferences.getInstance().then((prefs) {
      if (role != null) {
        prefs.setString('intended_role', role);
      } else {
        prefs.remove('intended_role');
      }
    });
  }
}
