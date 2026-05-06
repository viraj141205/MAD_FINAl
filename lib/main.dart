import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/appointment_provider.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/queue_status_screen.dart';
import 'screens/register_screen.dart';
import 'screens/search_filter_screen.dart';
import 'utils/slide_page_route.dart';
import 'utils/splash_screen.dart';

// Global notifier — true = online, false = offline.
final ValueNotifier<bool> isOnlineNotifier = ValueNotifier(true);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase init (do NOT call again — already done via FlutterFire CLI) ──
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Firestore offline persistence ─────────────────────────────────────────
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

// ── Root widget ────────────────────────────────────────────────────────────────

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _startConnectivityListener();
  }

  void _startConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      isOnlineNotifier.value = isOnline;
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppointmentProvider>(
      create: (_) => AppointmentProvider(),
      child: MaterialApp(
        title: 'AppointQ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1976D2),
            brightness: Brightness.light,
          ),
          primaryColor: const Color(0xFF1976D2),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1976D2),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          navigationBarTheme: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                );
              }
              return TextStyle(color: Colors.grey.shade600, fontSize: 11);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Color(0xFF1976D2), size: 24);
              }
              return IconThemeData(color: Colors.grey.shade500, size: 22);
            }),
          ),
          useMaterial3: true,
        ),

        // ── Named routes ─────────────────────────────────────────────────────
        initialRoute: '/',
        routes: {
          '/':         (ctx) => const SplashScreen(),
          '/auth':     (ctx) => const AuthGate(),
          '/main':     (ctx) => const MainScreen(),
          '/login':    (ctx) => const LoginScreen(),
          '/register': (ctx) => const RegisterScreen(),
          '/booking':  (ctx) => const BookingScreen(),
          '/search':   (ctx) => const SearchFilterScreen(),
          '/admin':    (ctx) => const AdminDashboardScreen(),
        },
        // QueueStatusScreen requires an Appointment argument
        onGenerateRoute: (settings) {
          if (settings.name == '/queue-status') {
            return SlidePageRoute(
              settings: settings,
              builder: (_) => QueueStatusScreen(
                appointment: settings.arguments as dynamic,
              ),
            );
          }
          return null;
        },
      ),
    );
  }
}

// ── Auth Gate ──────────────────────────────────────────────────────────────────

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const MainScreen();
        }
        return const LoginScreen();
      },
    );
  }
}

// ── Offline Banner ─────────────────────────────────────────────────────────────

/// Wrap any Scaffold body with this to show a red offline bar at the top.
/// Also shows a SnackBar when reconnecting.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _heightAnim;

  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    isOnlineNotifier.addListener(_onConnectivityChange);
    // Initialise to current state without animation
    if (!isOnlineNotifier.value) _ctrl.value = 1.0;
  }

  void _onConnectivityChange() {
    final isOnline = isOnlineNotifier.value;
    if (!isOnline) {
      _wasOffline = true;
      _ctrl.forward();
    } else {
      _ctrl.reverse();
      if (_wasOffline && mounted) {
        _wasOffline = false;
        // Firestore SDK automatically flushes pending offline writes and
        // resumes the snapshot stream — no need to restart it manually.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.wifi_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Back online — syncing…'),
            ]),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    isOnlineNotifier.removeListener(_onConnectivityChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Offline red bar ───────────────────────────────────────────────
        SizeTransition(
          sizeFactor: _heightAnim,
          child: Material(
            color: const Color(0xFFEF4444),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'You are offline — showing cached data',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  ValueListenableBuilder<bool>(
                    valueListenable: isOnlineNotifier,
                    builder: (_, online, __) => online
                        ? const SizedBox.shrink()
                        : const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 1.5),
                          ),
                  ),
                ]),
              ),
            ),
          ),
        ),

        // ── Actual screen content ─────────────────────────────────────────
        Expanded(child: widget.child),
      ],
    );
  }
}
