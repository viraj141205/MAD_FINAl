import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart' show OfflineBanner;
import 'admin_dashboard_screen.dart';
import 'appointment_list_screen.dart';
import 'booking_screen.dart';
import 'login_screen.dart';
import 'search_filter_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1; // default: My Queue tab

  static const String _adminPin = '1234';

  // ── Tab definitions ───────────────────────────────────────────────────────

  static const _tabs = [
    _TabDef(label: 'Book',     icon: Icons.add_circle_outline_rounded,
            activeIcon: Icons.add_circle_rounded),
    _TabDef(label: 'My Queue', icon: Icons.list_alt_outlined,
            activeIcon: Icons.list_alt_rounded),
    _TabDef(label: 'Search',   icon: Icons.search_rounded,
            activeIcon: Icons.manage_search_rounded),
  ];

  // Tab bodies held in IndexedStack so state is preserved between switches.
  static const _bodies = [
    BookingScreen(),
    AppointmentListScreen(),
    SearchFilterScreen(),
  ];

  static const _titles = ['Book Appointment', 'My Queue', 'Search & Filter'];

  // ── PIN Dialog ────────────────────────────────────────────────────────────

  Future<void> _showPinDialog() async {
    final pinCtrl = TextEditingController();
    String? errorMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFF1976D2)),
            SizedBox(width: 10),
            Text('Admin Access'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter the admin PIN to continue.',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '● ● ● ●',
                  filled: true,
                  fillColor: const Color(0xFFF5F9FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Color(0xFF1976D2), width: 1.8),
                  ),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(errorMsg!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                if (pinCtrl.text.trim() == _adminPin) {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminDashboardScreen()));
                } else {
                  setDialogState(
                      () => errorMsg = 'Incorrect PIN. Try again.');
                  pinCtrl.clear();
                }
              },
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );

    pinCtrl.dispose();
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: Color(0xFF1976D2)),
          SizedBox(width: 10),
          Text('Logout?'),
        ]),
        content: const Text(
            'Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),

      // ── AppBar ────────────────────────────────────────────────────────
      appBar: AppBar(
        title: RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'AppointQ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Admin dashboard (PIN-gated)
          IconButton(
            tooltip: 'Admin Dashboard',
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: _showPinDialog,
          ),
          // Logout
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _confirmLogout,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _titles[_currentIndex],
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),

      // ── Body: OfflineBanner wraps IndexedStack ──────────────────────────
      body: OfflineBanner(
        child: IndexedStack(
          index: _currentIndex,
          children: _bodies,
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          backgroundColor: Colors.white,
          indicatorColor: primary.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _tabs
              .map((t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.activeIcon, color: primary),
                    label: t.label,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ── Tab definition helper ──────────────────────────────────────────────────────

class _TabDef {
  const _TabDef({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
