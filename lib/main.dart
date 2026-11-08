
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

const Color navy = Color(0xFF172C48);
const Color background = Color(0xFFF5F7FA);
const Color coral = Color(0xFFE45459);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const SafeCircleApp());
}

// ================= APP =================

class SafeCircleApp extends StatelessWidget {
  const SafeCircleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeCircle',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        fontFamily: 'Arial',
      ),
      home: const AuthGate(),
    );
  }
}

// ================= AUTH GATE =================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const Dashboard();
        }

        return const AuthScreen();
      },
    );
  }
}

// ================= AUTH SCREEN =================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  bool isLogin = true;
  bool isLoading = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> saveUserProfile(User user, String name) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
      'name': name,
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> handleEmailAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty ||
        password.isEmpty ||
        (!isLogin && name.isEmpty)) {
      showMessage('Please fill in all required fields.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must contain at least 6 characters.');
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await credential.user?.updateDisplayName(name);

        if (credential.user != null) {
          await saveUserProfile(credential.user!, name);
        }
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Authentication failed.');
    } catch (e) {
      showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> handleGoogleSignIn() async {
    setState(() => isLoading = true);

    try {
      final provider = GoogleAuthProvider();

      final result =
          await FirebaseAuth.instance.signInWithPopup(provider);

      final user = result.user;

      if (user != null) {
        await saveUserProfile(
          user,
          user.displayName ?? 'SafeCircle User',
        );
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Google sign-in failed.');
    } catch (e) {
      showMessage('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Enter your email address first.');
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      showMessage('Password reset email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Could not send reset email.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.shield_rounded,
                      color: navy,
                      size: 55,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'SafeCircle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLogin
                          ? 'Welcome back! Stay safe.'
                          : 'Create your personal safety account.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 30),

                    if (!isLogin) ...[
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: resetPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),

                    const SizedBox(height: 15),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coral,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isLoading ? null : handleEmailAuth,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isLogin ? 'Login' : 'Create Account',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Row(
                      children: [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(color: Colors.blueGrey),
                          ),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),

                    const SizedBox(height: 18),

                    OutlinedButton.icon(
                      onPressed: isLoading ? null : handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin
                            ? "Don't have an account? Sign up"
                            : 'Already have an account? Login',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================= DASHBOARD =================

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int selectedIndex = 0;

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  // ================= SOS WORKFLOW =================

  Future<void> showSOSConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Emergency SOS'),
        content: const Text(
          'Are you sure you want to create an emergency alert? '
          'Your current location will be saved with the alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm SOS'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Getting your location...')),
    );

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw Exception(
          'Location services are disabled. Please enable location.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        throw Exception('Location permission was denied.');
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is permanently denied. '
          'Enable it in your browser settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Please log in again.');
      }

      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query='
          '${position.latitude},${position.longitude}';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('alerts')
          .add({
        'type': 'SOS',
        'status': 'Active',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'mapsUrl': mapsUrl,
        'userName': user.displayName ?? 'SafeCircle User',
        'userEmail': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'SOS alert saved successfully with your location!',
          ),
        ),
      );

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('SOS Alert Created'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 45,
              ),
              const SizedBox(height: 12),
              const Text('Your emergency alert has been saved.'),
              const SizedBox(height: 12),
              Text(
                'Latitude: ${position.latitude.toStringAsFixed(5)}',
              ),
              Text(
                'Longitude: ${position.longitude.toStringAsFixed(5)}',
              ),
              const SizedBox(height: 12),
              SelectableText(mapsUrl),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('SOS failed: $e'),
        ),
      );
    }
  }

  // ================= MAIN LAYOUT =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 750;

          return Row(
            children: [
              if (!isMobile) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(isMobile),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: _buildDashboardContent(isMobile),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 750
    ? NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Location',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      )
    : null,
    );
  }

  // ================= SIDEBAR =================

  Widget _buildSidebar() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      width: 235,
      color: navy,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 12),
          const Text(
            'SafeCircle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Stay connected. Stay protected.',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 45),

          _navItem(Icons.dashboard_outlined, 'Dashboard', 0),
          _navItem(Icons.people_outline, 'Trusted Contacts', 1),
          _navItem(Icons.location_on_outlined, 'Location', 2),
          _navItem(Icons.history, 'Alert History', 3),
          _navItem(Icons.settings_outlined, 'Settings', 4),

          const Spacer(),
          const Divider(color: Colors.white24),

          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(
              user?.displayName ?? 'My Account',
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        selected: selected,
        selectedTileColor: Colors.white.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icon,
          color: selected ? Colors.white : Colors.white70,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 13,
          ),
        ),
        onTap: () => setState(() => selectedIndex = index),
      ),
    );
  }

  // ================= TOP BAR =================

 Widget _buildTopBar(bool isMobile) {
  final user = FirebaseAuth.instance.currentUser;

  final pageTitles = [
    'Your Safety Dashboard',
    'Trusted Contacts',
    'My Location',
    'Alert History',
    'Settings',
  ];

  return Container(
    height: 76,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(
        bottom: BorderSide(color: Color(0xFFEAECEF)),
      ),
    ),
    child: Row(
      children: [
        Flexible(
          child: Text(
            pageTitles[selectedIndex],
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
        ),
        const Spacer(),

        if (isMobile)
          CircleAvatar(
            backgroundColor: const Color(0xFFE8EDF5),
            child: Text(
              (user?.displayName?.isNotEmpty == true
                      ? user!.displayName![0]
                      : 'U')
                  .toUpperCase(),
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        IconButton(
          tooltip: 'Logout',
          onPressed: logout,
          icon: const Icon(
            Icons.logout_rounded,
            color: coral,
          ),
        ),
      ],
    ),
  );
}

  // ================= DASHBOARD CONTENT =================

  
Widget _buildDashboardContent(bool isMobile) {
  switch (selectedIndex) {
    case 0:
      return _buildHomePage(isMobile);

    case 1:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Trusted Contacts',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          SizedBox(height: 8),
          Text('Manage your emergency contacts.'),
          SizedBox(height: 24),
          TrustedContactsSection(),
        ],
      );

    case 2:
      return const LocationPage();

    case 3:
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Alert History',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          SizedBox(height: 8),
          Text('Review your previously recorded SOS alerts.'),
          SizedBox(height: 24),
          AlertHistorySection(),
        ],
      );

    case 4:
      return SettingsPage(onLogout: logout);

    default:
      return _buildHomePage(isMobile);
  }
}

Widget _buildHomePage(bool isMobile) {
  final user = FirebaseAuth.instance.currentUser;
  final firstName = user?.displayName?.trim().split(' ').first;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Hello, ${firstName?.isNotEmpty == true ? firstName : 'there'}!',
        style: const TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.bold,
          color: navy,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Your safety matters. Stay connected with your trusted circle.',
        style: TextStyle(color: Colors.blueGrey),
      ),
      const SizedBox(height: 26),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: navy,
          borderRadius: BorderRadius.circular(20),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sosText(),
                  const SizedBox(height: 20),
                  Center(child: _sosButton()),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _sosText()),
                  _sosButton(),
                ],
              ),
      ),

      const SizedBox(height: 25),

      const Text(
        'Your Safety Overview',
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.bold,
          color: navy,
        ),
      ),
      const SizedBox(height: 15),

      Wrap(
        spacing: 15,
        runSpacing: 15,
        children: [
          _statCard(
            'Trusted Contacts',
            'Live',
            Icons.people_outline,
            const Color(0xFFE8F0FF),
          ),
          _statCard(
            'Safety Check-ins',
            'Coming soon',
            Icons.verified_user_outlined,
            const Color(0xFFE7F7EF),
          ),
          _statCard(
            'Recent Alerts',
            'Live',
            Icons.notifications_active_outlined,
            const Color(0xFFFFEEEE),
          ),
        ],
      ),
    ],
  );
}


  // ================= SOS UI =================

  Widget _sosText() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Need immediate help?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Use the SOS button to start an emergency alert workflow.',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _sosButton() {
    return InkWell(
      onTap: showSOSConfirmation,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: coral,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white30, width: 5),
          boxShadow: [
            BoxShadow(
              color: coral.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 3,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sos, color: Colors.white, size: 35),
            Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= STAT CARDS =================

  Widget _statCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: navy),
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: navy,
            ),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}

// ================= ALERT HISTORY =================

class AlertHistorySection extends StatelessWidget {
  const AlertHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Text('Please log in to view alerts.');
    }

    final alertsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('alerts');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: alertsRef
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load alert history. Check Firestore rules.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final alerts = snapshot.data?.docs ?? [];

        if (alerts.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEAECEF)),
            ),
            child: const Text(
              'No emergency alerts recorded yet.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: alerts.map((doc) {
            final data = doc.data();
            final timestamp = data['createdAt'] as Timestamp?;

            final date = timestamp == null
                ? 'Date pending'
                : timestamp.toDate().toLocal().toString().substring(0, 16);

            final latitude = data['latitude'] ?? 'Unavailable';
            final longitude = data['longitude'] ?? 'Unavailable';
            final mapsUrl = data['mapsUrl'] as String?;

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFEEEE),
                  child: Icon(Icons.sos, color: coral),
                ),
                title: Text(data['type'] ?? 'SOS Alert'),
                subtitle: Text(
                  'Status: ${data['status'] ?? 'Unknown'}\n'
                  '$date\n'
                  'Location: $latitude, $longitude',
                ),
                isThreeLine: true,
                trailing: mapsUrl == null
                    ? null
                    : IconButton(
                        tooltip: 'Show map link',
                        icon: const Icon(
                          Icons.location_on,
                          color: navy,
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: SelectableText(mapsUrl),
                              duration: const Duration(seconds: 8),
                            ),
                          );
                        },
                      ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ================= TRUSTED CONTACTS =================

class TrustedContactsSection extends StatefulWidget {
  const TrustedContactsSection({super.key});

  @override
  State<TrustedContactsSection> createState() =>
      _TrustedContactsSectionState();
}

class _TrustedContactsSectionState extends State<TrustedContactsSection> {
  final nameController = TextEditingController();
  final relationController = TextEditingController();
  final phoneController = TextEditingController();

  CollectionReference<Map<String, dynamic>> get contactsRef {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('User is not logged in.');
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('contacts');
  }

  @override
  void dispose() {
    nameController.dispose();
    relationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> addContact() async {
    nameController.clear();
    relationController.clear();
    phoneController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Trusted Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: relationController,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  prefixIcon: Icon(Icons.people_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty ||
                  phoneController.text.trim().isEmpty) {
                return;
              }

              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save Contact'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await contactsRef.add({
        'name': nameController.text.trim(),
        'relation': relationController.text.trim().isEmpty
            ? 'Contact'
            : relationController.text.trim(),
        'phone': phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact added successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding contact: $e')),
      );
    }
  }

  Future<void> deleteContact(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Contact?'),
        content: const Text(
          'Are you sure you want to remove this contact?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await contactsRef.doc(id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact removed!')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your Trusted Circle',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: navy,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: addContact,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),

        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: contactsRef.orderBy('createdAt').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'Unable to load contacts. Check Firestore rules.',
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final contacts = snapshot.data?.docs ?? [];

            if (contacts.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFEAECEF),
                  ),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 42,
                      color: Colors.blueGrey,
                    ),
                    SizedBox(height: 10),
                    Text(
                      'No trusted contacts yet',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: navy,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Add family or friends to your safety circle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.blueGrey),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: contacts.map((document) {
                final data = document.data();

                final name = data['name'] ?? 'Unknown';
                final relation = data['relation'] ?? 'Contact';
                final phone = data['phone'] ?? '';

                return Card(
                  color: Colors.white,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: const BorderSide(
                      color: Color(0xFFEAECEF),
                    ),
                  ),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8EDF5),
                      child: Icon(Icons.person, color: navy),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text('$relation • $phone'),
                    trailing: IconButton(
                      tooltip: 'Remove contact',
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => deleteContact(document.id),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? position;
  bool loading = false;
  String? error;

  Future<void> getLocation() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        throw Exception('Please enable location services.');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission was not granted.');
      }

      final result = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );

      if (!mounted) return;

      setState(() {
        position = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> openMap() async {
    if (position == null) return;

    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${position!.latitude},${position!.longitude}',
    );

    await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Location',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your current location and view it on Google Maps.',
        ),
        const SizedBox(height: 25),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEAECEF)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.location_on,
                color: coral,
                size: 55,
              ),
              const SizedBox(height: 15),

              if (position == null)
                const Text(
                  'Your location has not been retrieved yet.',
                  textAlign: TextAlign.center,
                )
              else ...[
                const Text(
                  'Location Retrieved',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'Latitude: ${position!.latitude}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Longitude: ${position!.longitude}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Accuracy: ${position!.accuracy.toStringAsFixed(1)} metres',
                ),
                const SizedBox(height: 15),
                ElevatedButton.icon(
                  onPressed: openMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Open in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],

              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : getLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                    loading ? 'Getting location...' : 'Get My Location',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= SETTINGS PAGE =================

class SettingsPage extends StatelessWidget {
  final VoidCallback onLogout;

  const SettingsPage({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: navy,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Manage your SafeCircle account.'),
        const SizedBox(height: 25),

        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_circle,
                  color: navy,
                  size: 55,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Account Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 15),
                Text('Name: ${user?.displayName ?? 'Not provided'}'),
                const SizedBox(height: 10),
                Text('Email: ${user?.email ?? 'Not available'}'),
                const SizedBox(height: 10),
                Text(
                  'Account: ${user?.emailVerified == true ? 'Verified' : 'Email not verified'}',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: coral,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(15),
            ),
          ),
        ),
      ],
    );
  }
}

