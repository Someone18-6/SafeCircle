import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';

/// Translates Firebase error codes into messages a normal person understands.
String friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-email':
      return 'That email address does not look right.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Incorrect email or password. Please try again.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'email-already-in-use':
      return 'An account already exists for this email. Try logging in.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'No internet connection. Please check your network.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled in Firebase.';
    default:
      return e.message ?? 'Authentication failed. Please try again.';
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    setState(() => _isLoading = true);

    try {
      final auth = FirebaseAuth.instance;
      if (_isLogin) {
        await auth.signInWithEmailAndPassword(email: email, password: password);
      } else {
        final credential = await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final created = credential.user;
        if (created != null) {
          await created.updateDisplayName(name);
          await AppServices.saveProfile(created, name);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e), error: true);
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Something went wrong: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final provider = GoogleAuthProvider();
      final auth = FirebaseAuth.instance;
      final result = kIsWeb
          ? await auth.signInWithPopup(provider)
          : await auth.signInWithProvider(provider);

      final account = result.user;
      if (account != null) {
        await AppServices.saveProfile(
          account,
          account.displayName ?? 'SafeCircle User',
        );
      }
    } on FirebaseAuthException catch (e) {
      final closed =
          e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request';
      if (!closed && mounted) {
        showAppSnack(context, friendlyAuthError(e), error: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Google sign-in failed: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();

    if (!isValidEmail(email)) {
      showAppSnack(
        context,
        'Enter your email address above first, then tap "Forgot password".',
        error: true,
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        showAppSnack(
          context,
          'Password reset email sent to $email. Check your inbox.',
          good: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) showAppSnack(context, friendlyAuthError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 920;

          if (wide) {
            return Row(
              children: [
                const Expanded(flex: 11, child: _BrandPanel()),
                Expanded(
                  flex: 10,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _buildForm(showLogo: false),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [navy, navyLight, background],
                stops: [0.0, 0.28, 0.28],
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _buildForm(showLogo: true),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm({required bool showLogo}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLogo) ...[
          const Icon(Icons.shield_rounded, color: Colors.white, size: 44),
          const SizedBox(height: 6),
          const Text(
            'SafeCircle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
        ],
        AppCard(
          padding: const EdgeInsets.all(28),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isLogin ? 'Welcome back' : 'Create your account',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'Log in to your SafeCircle dashboard.'
                        : 'Set up your personal safety network in a minute.',
                    style: const TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: fieldDecoration(
                        label: 'Full name',
                        icon: Icons.person_outline,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 2)
                          ? 'Please enter your name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: fieldDecoration(
                      label: 'Email address',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) => isValidEmail(value ?? '')
                        ? null
                        : 'Enter a valid email address',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    autofillHints: [
                      _isLogin
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    onFieldSubmitted: (_) => _isLoading ? null : _submit(),
                    decoration: fieldDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline,
                      suffix: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'Password must be at least 6 characters'
                        : null,
                  ),
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _resetPassword,
                        child: const Text('Forgot password?'),
                      ),
                    )
                  else
                    const SizedBox(height: 12),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coral,
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isLogin ? 'Log in' : 'Create account'),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR', style: TextStyle(color: muted)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _googleSignIn,
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF4285F4),
                      ),
                    ),
                    label: const Text('Continue with Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isLogin
                          ? "New to SafeCircle? Create an account"
                          : 'Already registered? Log in',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navy, navyLight],
        ),
      ),
      padding: const EdgeInsets.all(56),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 46,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'SafeCircle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Stay connected. Stay protected.',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 44),
          const _Feature(
            icon: Icons.sos_rounded,
            title: 'One-tap SOS',
            text: 'Save an emergency alert with your live GPS location.',
          ),
          const _Feature(
            icon: Icons.group_outlined,
            title: 'Trusted circle',
            text: 'Notify family and friends instantly by WhatsApp or SMS.',
          ),
          const _Feature(
            icon: Icons.verified_user_outlined,
            title: 'Safety check-ins',
            text: 'Let your circle know you have reached safely.',
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _Feature({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
