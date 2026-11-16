import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/app_provider.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/my_day/my_day_screen.dart';
import '../screens/productivity/todos_screen.dart';
import '../screens/navigation/navigation_screen.dart';
import '../screens/lifestyle/bills_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../features/health/presentation/pages/health_dashboard_page.dart';
import '../features/payment_scanner/screens/payment_scanner_screen.dart';

class MainNavigation extends StatefulWidget {
  final Widget? child;

  const MainNavigation({super.key, this.child});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  StreamSubscription? _intentDataStreamSubscription;

  final List<Widget> _screens = const [
    DashboardScreen(),
    MyDayScreen(),
    TodosScreen(),
    HealthDashboardPage(),
    NavigationScreen(),
    BillsScreen(),
    SettingsScreen(),
  ];

  final List<String> _routes = [
    '/',
    '/my_day',
    '/todos',
    '/health',
    '/navigation',
    '/bills',
    '/settings',
  ];

  @override
  void initState() {
    super.initState();
    _initShareIntentListener();
  }

  void _initShareIntentListener() {
    try {
      _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
        if (value.isNotEmpty) {
          _openScannerWithSharedImage(value.first.path);
        }
      }, onError: (err) {
        debugPrint('Share intent stream error: $err');
      });

      ReceiveSharingIntent.instance.getInitialMedia().then((value) {
        if (value.isNotEmpty) {
          _openScannerWithSharedImage(value.first.path);
        }
      }).catchError((err) {
        debugPrint('Initial share media error: $err');
      });
    } catch (e) {
      debugPrint('ReceiveSharingIntent init error: $e');
    }
  }

  Future<void> _openScannerWithSharedImage(String imagePath) async {
    if (!mounted) return;
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScannerScreen(initialImagePath: imagePath),
      ),
    );
    if (res == true && mounted) {
      try {
        Provider.of<AppProvider>(context, listen: false).notifyDataChanged();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: widget.child ??
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            indicatorColor: isDark ? const Color(0xFF38BDF8).withAlpha(45) : const Color(0xFF0284C7).withAlpha(30),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), size: 23);
              }
              return IconThemeData(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 21);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                );
              }
              return TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
            elevation: 0,
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
              if (widget.child != null) {
                context.go(_routes[index]);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today_rounded),
                label: 'My Day',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_alt_outlined),
                selectedIcon: Icon(Icons.task_alt_rounded),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_outline_rounded),
                selectedIcon: Icon(Icons.favorite_rounded),
                label: 'Health',
              ),
              NavigationDestination(
                icon: Icon(Icons.flight_takeoff_outlined),
                selectedIcon: Icon(Icons.flight_takeoff_rounded),
                label: 'Trips',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_outlined),
                selectedIcon: Icon(Icons.receipt_rounded),
                label: 'Bills',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
