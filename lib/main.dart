import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database/app_database.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart' hide AppThemeMode;
import 'core/providers/riverpod_providers.dart';
import 'core/router/app_router.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';
import 'services/app_notification_scheduler.dart';
import 'features/payment_scanner/services/auto_payment_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await AppDatabase.instance.database;
  } catch (e) {
    debugPrint('AppDatabase startup initialization error: $e');
  }

  try {
    await NotificationService.instance.init();
    await AppNotificationScheduler.instance.initAllScheduledNotifications();
    await AutoPaymentManager.instance.initialize();
  } catch (e) {
    debugPrint('NotificationService/AutoPayment startup initialization error: $e');
  }

  runApp(
    ProviderScope(
      child: p.ChangeNotifierProvider<AppProvider>(
        create: (_) => AppProvider(),
        child: const LifeSyncApp(),
      ),
    ),
  );
}

class LifeSyncApp extends ConsumerWidget {
  const LifeSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    ThemeData selectedTheme;
    switch (themeMode) {
      case AppThemeMode.dark:
        selectedTheme = AppTheme.darkTheme;
        break;
      case AppThemeMode.highContrast:
        selectedTheme = AppTheme.highContrastTheme;
        break;
      case AppThemeMode.light:
      default:
        selectedTheme = AppTheme.lightTheme;
        break;
    }

    return MaterialApp.router(
      title: 'LifeSync Tracker',
      debugShowCheckedModeBanner: false,
      theme: selectedTheme,
      routerConfig: router,
    );
  }
}
