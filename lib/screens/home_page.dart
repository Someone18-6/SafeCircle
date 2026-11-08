import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';
import 'activity_page.dart';

class HomePage extends StatefulWidget {
  final User? user;

  /// Lets quick actions jump to another tab (0 Home ... 4 Settings).
  final ValueChanged<int> onNavigate;

  const HomePage({super.key, required this.user, required this.onNavigate});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _sosBusy = false;
  bool _locationBusy = false;

  // ------------------------------------------------------------ SOS flow --

  Future<void> _startSos() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Send emergency SOS?',
      message:
          'An alert will be saved with your current location. '
          'You can then notify your trusted contacts in one tap.',
      confirmLabel: 'Yes, send SOS',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _sosBusy = true);

    Position? position;
    String? problem;
    try {
      position = await AppServices.currentPosition();
    } on LocationException catch (e) {
      // Still record the alert: an alert without coordinates beats none.
      problem = e.message;
    }

    var synced = true;
    try {
      await AppServices.createSosAlert(
        position: position,
        locationProblem: problem,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          synced = false;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _sosBusy = false);
        showAppSnack(context, 'Could not save the alert: $e', error: true);
      }
      return;
    }

    if (!mounted) return;
    setState(() => _sosBusy = false);
    await _showSosResult(position, problem, synced);
  }

  Future<void> _showSosResult(
    Position? position,
    String? problem,
    bool synced,
  ) {
    final message = buildSosMessage(
      name: AppServices.displayName,
      latitude: position?.latitude,
      longitude: position?.longitude,
    );

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: success, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'SOS alert recorded',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (position != null)
                  _InfoBox(
                    color: successSoft,
                    icon: Icons.my_location,
                    text:
                        'Location saved\n'
                        'Lat ${position.latitude.toStringAsFixed(5)}, '
                        'Lng ${position.longitude.toStringAsFixed(5)} '
                        '(\u00B1${position.accuracy.toStringAsFixed(0)} m)',
                  )
                else
                  _InfoBox(
                    color: amberSoft,
                    icon: Icons.warning_amber_rounded,
                    text:
                        'Location unavailable. ${problem ?? ''}\n'
                        'Your contacts will be asked to call you.',
                  ),
                if (!synced) ...[
                  const SizedBox(height: 10),
                  const _InfoBox(
                    color: amberSoft,
                    icon: Icons.cloud_off_outlined,
                    text:
                        'You seem to be offline. The alert is stored on '
                        'this device and uploads automatically when you '
                        'reconnect.',
                  ),
                ],
                const SizedBox(height: 18),
                const Text(
                  'Next step: tell your trusted circle',
                  style: TextStyle(fontWeight: FontWeight.w700, color: navy),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: coral),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    if (!mounted) return;
                    showShareSheet(
                      context,
                      title: 'Notify trusted contacts',
                      message: message,
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Notify my contacts'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _callEmergency,
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Call emergency services'),
                ),
                if (position != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openOrWarn(
                      context,
                      Uri.parse(
                        mapsLink(position.latitude, position.longitude),
                      ),
                      failure: 'Could not open Google Maps.',
                    ),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: const Text('Open in Google Maps'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _callEmergency() async {
    final number = await AppServices.emergencyNumber();
    if (!mounted) return;
    await openOrWarn(
      context,
      telUri(number),
      failure:
          'Calling is not supported on this device. '
          'Please dial $number manually.',
    );
  }

  // ------------------------------------------------------ other actions ---

  Future<void> _checkIn() async {
    final result = await showDialog<(String, bool)>(
      context: context,
      builder: (_) => const _CheckInDialog(),
    );
    if (result == null || !mounted) return;

    final (note, notify) = result;
    var synced = true;

    try {
      await AppServices.createCheckIn(note: note).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          synced = false;
        },
      );
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Could not save check-in: $e', error: true);
      }
      return;
    }

    if (!mounted) return;
    showAppSnack(
      context,
      synced
          ? 'Check-in recorded. Stay safe!'
          : 'Check-in saved on this device and will sync when you are online.',
      good: synced,
    );

    if (notify) {
      final extra = note.trim().isEmpty ? '' : ' Note: ${note.trim()}';
      showShareSheet(
        context,
        title: 'Tell your contacts you are safe',
        message:
            '${AppServices.displayName} has checked in: '
            'I am safe.$extra (sent via SafeCircle)',
      );
    }
  }

  Future<void> _shareLocation() async {
    setState(() => _locationBusy = true);
    try {
      final position = await AppServices.currentPosition();
      if (!mounted) return;
      showShareSheet(
        context,
        title: 'Share my location',
        message: buildLocationMessage(
          name: AppServices.displayName,
          latitude: position.latitude,
          longitude: position.longitude,
        ),
      );
    } on LocationException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _locationBusy = false);
    }
  }

  // --------------------------------------------------------------- build --

  @override
  Widget build(BuildContext context) {
    final fullName = widget.user?.displayName?.trim() ?? '';
    final firstName = fullName.isEmpty ? 'there' : fullName.split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${greetingFor(DateTime.now())}, $firstName',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: navy,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Your safety matters. Your circle is one tap away.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 22),
        _buildHero(),
        const SizedBox(height: 22),
        _buildStats(),
        const SizedBox(height: 26),
        const SectionTitle('Quick actions'),
        _buildQuickActions(),
        const SizedBox(height: 26),
        SectionTitle(
          'Recent SOS alerts',
          trailing: TextButton(
            onPressed: () => widget.onNavigate(3),
            child: const Text('View all'),
          ),
        ),
        _buildRecentAlerts(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navy, navyLight],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33172C48),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 560;

          final text = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Need immediate help?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Press SOS to save an emergency alert with your live location, '
                'then notify your trusted contacts instantly.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(icon: Icons.my_location, label: 'Live GPS'),
                  _HeroChip(icon: Icons.group_outlined, label: 'Alerts circle'),
                  _HeroChip(icon: Icons.lock_outline, label: 'Private'),
                ],
              ),
            ],
          );

          final button = _SosButton(busy: _sosBusy, onPressed: _startSos);

          if (narrow) {
            return Column(children: [text, const SizedBox(height: 14), button]);
          }
          return Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: 24),
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStats() {
    final contactsCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.contacts.snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length;
        return StatCard(
          icon: Icons.people_outline,
          tint: blueSoft,
          label: 'Trusted contacts',
          value: count?.toString() ?? '-',
          caption: count == null
              ? 'Loading...'
              : (count == 0 ? 'Add your first contact' : 'Ready to be alerted'),
        );
      },
    );

    final checkInCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.checkins
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs;
        if (docs == null) {
          return const StatCard(
            icon: Icons.verified_user_outlined,
            tint: successSoft,
            label: 'Check-ins this week',
            value: '-',
            caption: 'Loading...',
          );
        }

        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final thisWeek = docs.where((doc) {
          final time = (doc.data()['createdAt'] as Timestamp?)?.toDate();
          return time == null || time.isAfter(weekAgo);
        }).length;

        final latest = docs.isEmpty
            ? null
            : (docs.first.data()['createdAt'] as Timestamp?)?.toDate();

        return StatCard(
          icon: Icons.verified_user_outlined,
          tint: successSoft,
          label: 'Check-ins this week',
          value: '$thisWeek',
          caption: docs.isEmpty
              ? 'No check-ins yet'
              : 'Last: ${latest == null ? 'just now' : timeAgo(latest)}',
        );
      },
    );

    final alertsCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.alerts.snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs;
        final active = docs
            ?.where((d) => d.data()['status'] == 'Active')
            .length;
        return StatCard(
          icon: Icons.notifications_active_outlined,
          tint: coralSoft,
          label: 'Active SOS alerts',
          value: active?.toString() ?? '-',
          caption: active == null
              ? 'Loading...'
              : (active == 0 ? 'All clear' : 'Mark resolved in Activity'),
        );
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: contactsCard),
              const SizedBox(width: 14),
              Expanded(child: checkInCard),
              const SizedBox(width: 14),
              Expanded(child: alertsCard),
            ],
          );
        }
        return Column(
          children: [
            contactsCard,
            const SizedBox(height: 12),
            checkInCard,
            const SizedBox(height: 12),
            alertsCard,
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = 12.0;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        Widget tile(_ActionTile t) => SizedBox(width: tileWidth, child: t);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            tile(
              _ActionTile(
                icon: Icons.verified_user_outlined,
                tint: successSoft,
                title: "I'm safe",
                subtitle: 'Record a check-in',
                onTap: _checkIn,
              ),
            ),
            tile(
              _ActionTile(
                icon: Icons.share_location_outlined,
                tint: blueSoft,
                title: 'Share location',
                subtitle: 'Send where you are',
                busy: _locationBusy,
                onTap: _shareLocation,
              ),
            ),
            tile(
              _ActionTile(
                icon: Icons.call_outlined,
                tint: coralSoft,
                title: 'Emergency call',
                subtitle: 'Dial emergency services',
                onTap: _callEmergency,
              ),
            ),
            tile(
              _ActionTile(
                icon: Icons.person_add_alt_1_outlined,
                tint: amberSoft,
                title: 'Add contact',
                subtitle: 'Grow your circle',
                onTap: () => widget.onNavigate(1),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentAlerts() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AppServices.alerts
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const ErrorNotice(
            'Could not load alerts. Check your Firestore rules.',
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const EmptyState(
            icon: Icons.shield_outlined,
            title: 'No alerts yet',
            message: 'Any SOS alert you send will be listed here.',
          );
        }

        return Column(
          children: [
            for (final doc in docs) AlertCard(doc: doc, compact: true),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _InfoBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;

  const _InfoBox({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: navy),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;

  const _ActionTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: tint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(icon, color: navy, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: navy,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Big round SOS button with a soft pulsing ring.
class _SosButton extends StatefulWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _SosButton({required this.busy, required this.onPressed});

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send emergency SOS alert',
      child: SizedBox(
        width: 176,
        height: 176,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_pulse.value);
                final size = 116 + 58 * t;
                return Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: coral.withValues(alpha: 0.38 * (1 - t)),
                  ),
                );
              },
            ),
            Material(
              color: coral,
              elevation: 8,
              shadowColor: coral,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white38, width: 4),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: widget.busy ? null : widget.onPressed,
                child: SizedBox(
                  width: 116,
                  height: 116,
                  child: widget.busy
                      ? const Center(
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sos_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog that owns its text controller so it is disposed safely.
class _CheckInDialog extends StatefulWidget {
  const _CheckInDialog();

  @override
  State<_CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<_CheckInDialog> {
  final _noteController = TextEditingController();
  bool _notify = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text(
        "Safety check-in",
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Record that you are safe right now. You can add a short '
                'note such as where you are.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLength: 120,
                maxLines: 2,
                decoration: fieldDecoration(
                  label: 'Note (optional)',
                  hint: 'e.g. Reached home safely',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _notify,
                activeThumbColor: success,
                title: const Text('Also tell my contacts'),
                subtitle: const Text('Opens SMS / WhatsApp after saving'),
                onChanged: (value) => setState(() => _notify = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: success,
            minimumSize: const Size(0, 42),
          ),
          onPressed: () =>
              Navigator.pop(context, (_noteController.text.trim(), _notify)),
          icon: const Icon(Icons.check, size: 18),
          label: const Text("I'm safe"),
        ),
      ],
    );
  }
}
