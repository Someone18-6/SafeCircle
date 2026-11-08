import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';
import 'activity_page.dart';
import 'contacts_page.dart';
import 'home_page.dart';
import 'location_page.dart';
import 'settings_page.dart';

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Destination(this.icon, this.selectedIcon, this.label);
}

const List<_Destination> _destinations = [
  _Destination(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Home'),
  _Destination(Icons.people_outline, Icons.people, 'Contacts'),
  _Destination(Icons.location_on_outlined, Icons.location_on, 'Location'),
  _Destination(Icons.history, Icons.history, 'Activity'),
  _Destination(Icons.settings_outlined, Icons.settings, 'Settings'),
];

/// The signed-in area: a sidebar on large screens and a bottom navigation
/// bar on phones.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  Future<void> _logout() async {
    final ok = await confirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to use SafeCircle.',
      confirmLabel: 'Log out',
    );
    if (!ok) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) showAppSnack(context, 'Logout failed: $e', error: true);
    }
  }

  Widget _page(User? user) {
    switch (_index) {
      case 0:
        return HomePage(user: user, onNavigate: _go);
      case 1:
        return const ContactsPage();
      case 2:
        return const LocationPage();
      case 3:
        return const ActivityPage();
      default:
        return SettingsPage(user: user, onLogout: _logout);
    }
  }

  @override
  Widget build(BuildContext context) {
    // userChanges() also fires when the profile (e.g. display name) changes,
    // so the greeting and sidebar update immediately after an edit.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data;

        return LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= desktopBreakpoint;

            return Scaffold(
              body: Row(
                children: [
                  if (desktop)
                    _Sidebar(
                      user: user,
                      selectedIndex: _index,
                      onSelect: _go,
                      onLogout: _logout,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!desktop)
                          _MobileHeader(user: user, onProfileTap: () => _go(4)),
                        Expanded(child: _buildContent(user, desktop)),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: desktop
                  ? null
                  : NavigationBar(
                      selectedIndex: _index,
                      onDestinationSelected: _go,
                      destinations: [
                        for (final d in _destinations)
                          NavigationDestination(
                            icon: Icon(d.icon),
                            selectedIcon: Icon(d.selectedIcon, color: navy),
                            label: d.label,
                          ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildContent(User? user, bool desktop) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: SingleChildScrollView(
        // primary: false avoids two scroll views fighting over one controller
        // while AnimatedSwitcher cross-fades between pages.
        primary: false,
        key: ValueKey<int>(_index),
        padding: EdgeInsets.fromLTRB(
          desktop ? 36 : 18,
          desktop ? 32 : 20,
          desktop ? 36 : 18,
          32,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: _page(user),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Sidebar extends StatelessWidget {
  final User? user;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.user,
    required this.selectedIndex,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'My Account';

    return Container(
      width: 270,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [navy, navyDark],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SafeCircle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Stay connected. Stay protected.',
                      style: TextStyle(color: Colors.white60, fontSize: 10.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          for (var i = 0; i < _destinations.length; i++)
            _SidebarItem(
              destination: _destinations[i],
              selected: selectedIndex == i,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: coral,
                  child: Text(
                    initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Log out',
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (selected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: coral,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  final User? user;
  final VoidCallback onProfileTap;

  const _MobileHeader({required this.user, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';

    return Container(
      color: navy,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 10),
              const Text(
                'SafeCircle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              InkWell(
                customBorder: const CircleBorder(),
                onTap: onProfileTap,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: coral,
                  child: Text(
                    initials(name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
