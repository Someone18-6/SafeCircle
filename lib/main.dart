import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/dashboard_shell.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SafeCircleApp());
}

/// Root widget: sets the theme and decides between login and dashboard.
class SafeCircleApp extends StatelessWidget {
  const SafeCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeCircle - Personal Safety',
      theme: buildTheme(),
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase Auth and shows the right screen automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: navy)),
          );
        }

        if (snapshot.hasData) {
          return const DashboardShell();
        }

        return const AuthScreen();
      },
    );
  }
}
