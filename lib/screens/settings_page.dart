import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';

/// Emergency numbers the user can choose from.
const Map<String, String> _emergencyOptions = {
  '112': '112  India / Europe',
  '911': '911  USA / Canada',
  '999': '999  UK',
  '100': '100  Police (India)',
  '108': '108  Ambulance (India)',
};

class SettingsPage extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;

  const SettingsPage({super.key, required this.user, required this.onLogout});

  Future<void> _editName(BuildContext context) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: user?.displayName ?? ''),
    );
    if (newName == null || !context.mounted) return;

    try {
      final current = FirebaseAuth.instance.currentUser;
      await current?.updateDisplayName(newName);
      await current?.reload();
      await AppServices.userDoc.set({'name': newName}, SetOptions(merge: true));
      if (context.mounted) showAppSnack(context, 'Name updated', good: true);
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not update name: $e', error: true);
      }
    }
  }

  Future<void> _verifyEmail(BuildContext context) async {
    try {
      await user?.sendEmailVerification();
      if (context.mounted) {
        showAppSnack(
          context,
          'Verification email sent to ${user?.email}.',
          good: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        showAppSnack(
          context,
          e.message ?? 'Could not send email.',
          error: true,
        );
      }
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    final email = user?.email;
    if (email == null) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        showAppSnack(
          context,
          'Password reset link sent to $email.',
          good: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        showAppSnack(
          context,
          e.message ?? 'Could not send email.',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName?.trim() ?? '';
    final usesPassword =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;
    final verified = user?.emailVerified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Settings',
          subtitle: 'Manage your profile, emergency number and account.',
        ),

        // ------------------------------------------------------ profile --
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: navy,
                    child: Text(
                      initials(name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'No name set' : name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'No email',
                          style: const TextStyle(color: muted),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: verified ? 'Verified' : 'Not verified',
                    background: verified ? successSoft : amberSoft,
                    foreground: verified ? success : amber,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _editName(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit name'),
                  ),
                  if (!verified && user?.email != null)
                    OutlinedButton.icon(
                      onPressed: () => _verifyEmail(context),
                      icon: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 18,
                      ),
                      label: const Text('Verify email'),
                    ),
                  if (usesPassword)
                    OutlinedButton.icon(
                      onPressed: () => _resetPassword(context),
                      icon: const Icon(Icons.lock_reset, size: 18),
                      label: const Text('Reset password'),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ------------------------------------------- emergency number --
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.call_outlined, color: navy),
                  SizedBox(width: 10),
                  Text(
                    'Emergency number',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Used by the "Emergency call" and SOS call buttons.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 14),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: AppServices.userDoc.snapshots(),
                builder: (context, snapshot) {
                  final saved = snapshot.data?.data()?['emergencyNumber'];
                  final selected = (saved is String && saved.isNotEmpty)
                      ? saved
                      : AppServices.defaultEmergencyNumber;

                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _emergencyOptions.entries)
                        ChoiceChip(
                          label: Text(entry.value),
                          selected: selected == entry.key,
                          selectedColor: blueSoft,
                          backgroundColor: Colors.white,
                          onSelected: (_) async {
                            try {
                              await AppServices.setEmergencyNumber(entry.key);
                              if (context.mounted) {
                                showAppSnack(
                                  context,
                                  'Emergency number set to ${entry.key}',
                                  good: true,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                showAppSnack(
                                  context,
                                  'Could not save: $e',
                                  error: true,
                                );
                              }
                            }
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ----------------------------------------------------- about --
        const AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: navy),
                  SizedBox(width: 10),
                  Text(
                    'About SafeCircle',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: navy,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                'Version 1.0.0\n'
                'A personal safety app built with Flutter and Firebase. '
                'Your contacts, alerts and check-ins are stored privately '
                'under your own account.',
                style: TextStyle(color: muted, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: coral,
              minimumSize: const Size(0, 52),
            ),
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, _controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        'Edit your name',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onFieldSubmitted: (_) => _save(),
            decoration: fieldDecoration(
              label: 'Full name',
              icon: Icons.person_outline,
            ),
            validator: (v) => (v == null || v.trim().length < 2)
                ? 'Please enter your name'
                : null,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 42)),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
