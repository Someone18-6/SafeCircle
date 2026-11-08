import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';

const List<String> _relationOptions = [
  'Family',
  'Friend',
  'Partner',
  'Colleague',
  'Other',
];

class _ContactData {
  final String name;
  final String relation;
  final String phone;

  const _ContactData(this.name, this.relation, this.phone);
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  Future<void> _openEditor(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? existing,
  }) async {
    final result = await showDialog<_ContactData>(
      context: context,
      builder: (_) => _ContactDialog(
        initialName: existing?.data()['name'] ?? '',
        initialRelation: existing?.data()['relation'] ?? 'Family',
        initialPhone: existing?.data()['phone'] ?? '',
        isEditing: existing != null,
      ),
    );
    if (result == null || !context.mounted) return;

    try {
      await AppServices.saveContact(
        id: existing?.id,
        name: result.name,
        relation: result.relation,
        phone: result.phone,
      ).timeout(const Duration(seconds: 10));

      if (context.mounted) {
        showAppSnack(
          context,
          existing == null ? 'Contact added' : 'Contact updated',
          good: true,
        );
      }
    } on TimeoutException {
      // Firestore keeps the write queued while offline and syncs it later.
      if (context.mounted) {
        showAppSnack(
          context,
          'No connection. The contact is stored on this device and will '
          'sync when you are back online.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not save contact: $e', error: true);
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove contact?',
      message:
          '${doc.data()['name'] ?? 'This contact'} will no longer be '
          'part of your trusted circle.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await AppServices.deleteContact(doc.id);
      if (context.mounted) showAppSnack(context, 'Contact removed');
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not remove contact: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Trusted contacts',
          subtitle: 'The people who are alerted when you need help.',
          action: ElevatedButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add contact'),
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: AppServices.contacts.orderBy('createdAt').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const ErrorNotice(
                'Unable to load contacts. Check your internet connection '
                'and Firestore rules.',
              );
            }
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return EmptyState(
                icon: Icons.people_outline,
                title: 'No trusted contacts yet',
                message:
                    'Add family or friends so they can be notified '
                    'the moment you send an SOS.',
                action: ElevatedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add your first contact'),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                const gap = 14.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final doc in docs)
                      SizedBox(
                        width: width,
                        child: _ContactCard(
                          doc: doc,
                          onEdit: () => _openEditor(context, existing: doc),
                          onDelete: () => _delete(context, doc),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final String name = data['name'] ?? 'Unknown';
    final String relation = data['relation'] ?? 'Contact';
    final String phone = data['phone'] ?? '';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: blueSoft,
                child: Text(
                  initials(name),
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: const TextStyle(color: muted, fontSize: 13.5),
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: relation,
                background: blueSoft,
                foreground: navy,
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: coralDark),
                        SizedBox(width: 10),
                        Text('Remove', style: TextStyle(color: coralDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ContactActionRow(
            phone: phone,
            message:
                'Hi $name, this is ${AppServices.displayName} '
                '(sent via SafeCircle).',
          ),
        ],
      ),
    );
  }
}

/// Add / edit dialog. Owns its controllers so they are disposed safely.
class _ContactDialog extends StatefulWidget {
  final String initialName;
  final String initialRelation;
  final String initialPhone;
  final bool isEditing;

  const _ContactDialog({
    required this.initialName,
    required this.initialRelation,
    required this.initialPhone,
    required this.isEditing,
  });

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhone,
  );
  late String _relation = widget.initialRelation;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ContactData(_name.text.trim(), _relation, _phone.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(
        widget.isEditing ? 'Edit contact' : 'Add trusted contact',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: fieldDecoration(
                    label: 'Full name',
                    icon: Icons.person_outline,
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Please enter a name'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: fieldDecoration(
                    label: 'Phone number',
                    hint: '+91 98765 43210',
                    helper: 'Include the country code for WhatsApp',
                    icon: Icons.phone_outlined,
                  ),
                  validator: (v) => isValidPhone(v ?? '')
                      ? null
                      : 'Enter a valid phone number (7-15 digits)',
                ),
                const SizedBox(height: 18),
                const Text(
                  'Relationship',
                  style: TextStyle(fontWeight: FontWeight.w700, color: navy),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _relationOptions)
                      ChoiceChip(
                        label: Text(option),
                        selected: _relation == option,
                        selectedColor: blueSoft,
                        backgroundColor: Colors.white,
                        onSelected: (_) => setState(() => _relation = option),
                      ),
                  ],
                ),
              ],
            ),
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
          child: Text(widget.isEditing ? 'Save changes' : 'Save contact'),
        ),
      ],
    );
  }
}
