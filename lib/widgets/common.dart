import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';

// ---------------------------------------------------------------------------
// Feedback helpers
// ---------------------------------------------------------------------------

void showAppSnack(
  BuildContext context,
  String message, {
  bool error = false,
  bool good = false,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: error ? coralDark : (good ? success : navy),
      content: Row(
        children: [
          Icon(
            error
                ? Icons.error_outline
                : (good ? Icons.check_circle_outline : Icons.info_outline),
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );
}

/// Opens [uri] and tells the user if the device could not handle it.
Future<void> openOrWarn(
  BuildContext context,
  Uri uri, {
  String failure = 'This action is not supported on this device.',
}) async {
  final ok = await AppServices.open(uri);
  if (!ok && context.mounted) {
    showAppSnack(context, failure, error: true);
  }
}

Future<void> copyWithFeedback(
  BuildContext context,
  String text, {
  String message = 'Copied to clipboard',
}) async {
  await AppServices.copy(text);
  if (context.mounted) showAppSnack(context, message, good: true);
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: destructive ? coralDark : navy,
            minimumSize: const Size(0, 42),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

// ---------------------------------------------------------------------------
// Layout building blocks
// ---------------------------------------------------------------------------

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 14,
        spacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: navy,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: muted)),
            ],
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A172C48),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: navy,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: blueSoft,
            child: Icon(icon, color: navy, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class ErrorNotice extends StatelessWidget {
  final String message;
  const ErrorNotice(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: coralSoft,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: coralDark),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String caption;

  const StatCard({
    super.key,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: navy),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: muted, fontSize: 13)),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: navy,
                    height: 1.15,
                  ),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact actions (call / SMS / WhatsApp)
// ---------------------------------------------------------------------------

/// Row of three equal buttons that contact a person.
/// When [message] is given, SMS and WhatsApp are pre-filled with it.
class ContactActionRow extends StatelessWidget {
  final String phone;
  final String message;
  final bool showCall;

  const ContactActionRow({
    super.key,
    required this.phone,
    required this.message,
    this.showCall = true,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      if (showCall)
        _ActionButton(
          icon: Icons.call_outlined,
          label: 'Call',
          onTap: () => openOrWarn(
            context,
            telUri(phone),
            failure:
                'Calling is not supported on this device. '
                'Number: ${cleanPhone(phone)}',
          ),
        ),
      _ActionButton(
        icon: Icons.sms_outlined,
        label: 'SMS',
        onTap: () => openOrWarn(
          context,
          smsUri(phone, message),
          failure:
              'SMS is not supported on this device. Try WhatsApp or copy '
              'the message instead.',
        ),
      ),
      _ActionButton(
        icon: Icons.chat_outlined,
        label: 'WhatsApp',
        onTap: () => openOrWarn(
          context,
          whatsappUri(phone, message),
          failure:
              'Could not open WhatsApp. Check that the number includes '
              'its country code.',
        ),
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "Send to trusted contacts" bottom sheet
// ---------------------------------------------------------------------------

/// Lists every trusted contact with SMS / WhatsApp buttons that are pre-filled
/// with [message]. Also lets the user copy the message.
Future<void> showShareSheet(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    constraints: const BoxConstraints(maxWidth: 560),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _ShareSheet(title: title, message: message),
  );
}

class _ShareSheet extends StatelessWidget {
  final String title;
  final String message;

  const _ShareSheet({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: SelectableText(message),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => copyWithFeedback(
                    context,
                    message,
                    message: 'Message copied',
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy message'),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Send to',
                style: TextStyle(fontWeight: FontWeight.w700, color: navy),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: AppServices.contacts.orderBy('createdAt').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const ErrorNotice('Could not load your contacts.');
                  }
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Text(
                      'You have no trusted contacts yet. Add one from the '
                      'Contacts tab so you can notify them in an emergency.',
                      style: TextStyle(color: muted),
                    );
                  }

                  return Column(
                    children: [
                      for (final doc in docs)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.data()['name'] ?? 'Contact',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '${doc.data()['relation'] ?? 'Contact'}'
                                  ' \u2022 ${doc.data()['phone'] ?? ''}',
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ContactActionRow(
                                  phone: '${doc.data()['phone'] ?? ''}',
                                  message: message,
                                  showCall: false,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
