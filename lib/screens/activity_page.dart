import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';

/// History of SOS alerts and safety check-ins.
class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});

  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'Activity',
          subtitle: 'Review your SOS alerts and safety check-ins.',
        ),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Icons.sos_rounded),
              label: Text('SOS alerts'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.verified_user_outlined),
              label: Text('Check-ins'),
            ),
          ],
          selected: {_tab},
          onSelectionChanged: (selection) =>
              setState(() => _tab = selection.first),
        ),
        const SizedBox(height: 18),
        if (_tab == 0) const _AlertsList() else const _CheckInsList(),
      ],
    );
  }
}

// ---------------------------------------------------------------- alerts --

class _AlertsList extends StatelessWidget {
  const _AlertsList();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.alerts
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorNotice(
            'Unable to load alerts. Check your connection and Firestore rules.',
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
          return const EmptyState(
            icon: Icons.shield_outlined,
            title: 'No SOS alerts recorded',
            message:
                'When you send an SOS from the home screen, it will '
                'be listed here with its location.',
          );
        }

        return Column(children: [for (final doc in docs) AlertCard(doc: doc)]);
      },
    );
  }
}

/// One SOS alert. [compact] hides the action buttons (used on the home page).
class AlertCard extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final bool compact;

  const AlertCard({super.key, required this.doc, this.compact = false});

  Future<void> _resolve(BuildContext context) async {
    try {
      await AppServices.resolveAlert(doc.id);
      if (context.mounted) {
        showAppSnack(context, 'Alert marked as resolved', good: true);
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not update alert: $e', error: true);
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this alert?',
      message: 'It will be permanently removed from your history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await AppServices.deleteAlert(doc.id);
      if (context.mounted) showAppSnack(context, 'Alert deleted');
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not delete alert: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final String status = data['status'] ?? 'Active';
    final bool active = status == 'Active';
    final time = (data['createdAt'] as Timestamp?)?.toDate();
    final double? lat = (data['latitude'] as num?)?.toDouble();
    final double? lng = (data['longitude'] as num?)?.toDouble();
    final String? mapsUrl = data['mapsUrl'] as String?;

    final dateText = time == null
        ? 'Saving...'
        : '${formatDateTime(time)}  \u2022  ${timeAgo(time)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: active ? coralSoft : successSoft,
                  child: Icon(
                    active ? Icons.sos_rounded : Icons.check_rounded,
                    color: active ? coral : success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['type'] ?? 'SOS'} alert',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: navy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: status,
                  background: active ? coralSoft : successSoft,
                  foreground: active ? coralDark : success,
                ),
              ],
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18, color: muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lat == null || lng == null
                          ? 'Location was unavailable for this alert'
                          : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(color: muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (mapsUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => openOrWarn(
                        context,
                        Uri.parse(mapsUrl),
                        failure: 'Could not open Google Maps.',
                      ),
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('View on map'),
                    ),
                  if (mapsUrl != null)
                    OutlinedButton.icon(
                      onPressed: () => copyWithFeedback(
                        context,
                        mapsUrl,
                        message: 'Map link copied',
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy link'),
                    ),
                  if (active)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: success,
                        minimumSize: const Size(0, 46),
                      ),
                      onPressed: () => _resolve(context),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark resolved'),
                    ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: coralDark),
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- check-ins --

class _CheckInsList extends StatelessWidget {
  const _CheckInsList();

  Future<void> _delete(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete check-in?',
      message: 'This check-in will be removed from your history.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !context.mounted) return;

    try {
      await AppServices.deleteCheckIn(doc.id);
      if (context.mounted) showAppSnack(context, 'Check-in deleted');
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, 'Could not delete check-in: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.checkins
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorNotice(
            'Unable to load check-ins. Check your connection and '
            'Firestore rules.',
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
          return const EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'No check-ins yet',
            message:
                'Use the "I\'m safe" button on the home screen to '
                'record that you are okay.',
          );
        }

        return Column(
          children: [
            for (final doc in docs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CheckInTile(
                  doc: doc,
                  onDelete: () => _delete(context, doc),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CheckInTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onDelete;

  const _CheckInTile({required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final time = (data['createdAt'] as Timestamp?)?.toDate();
    final String note = (data['note'] as String?) ?? '';

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 22,
            backgroundColor: successSoft,
            child: Icon(Icons.verified_user_outlined, color: success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Checked in: I'm safe",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time == null
                      ? 'Saving...'
                      : '${formatDateTime(time)}  \u2022  ${timeAgo(time)}',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
                if (note.isNotEmpty) ...[const SizedBox(height: 6), Text(note)],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete check-in',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, color: coralDark),
          ),
        ],
      ),
    );
  }
}
