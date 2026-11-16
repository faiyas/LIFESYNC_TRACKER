import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/riverpod_providers.dart';
import '../../screens/auth/lock_screen.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/my_day/my_day_screen.dart';
import '../../screens/finance/expenses_screen.dart';
import '../../screens/finance/income_screen.dart';
import '../../screens/finance/budget_screen.dart';
import '../../screens/finance/savings_screen.dart';
import '../../screens/finance/loans_screen.dart';
import '../../screens/finance/borrowed_money_screen.dart';
import '../../screens/finance/net_worth_screen.dart';
import '../../screens/productivity/todos_screen.dart';
import '../../screens/productivity/habits_screen.dart';
import '../../screens/productivity/reminders_screen.dart';
import '../../screens/productivity/notes_screen.dart';
import '../../screens/productivity/journal_screen.dart';
import '../../screens/lifestyle/bills_screen.dart';
import '../../screens/lifestyle/vehicles_screen.dart';
import '../../screens/lifestyle/travel_screen.dart';
import '../../screens/lifestyle/group_expenses_screen.dart';
import '../../screens/lifestyle/health_score_screen.dart';
import '../../screens/business/customers_screen.dart';
import '../../screens/business/inventory_screen.dart';
import '../../screens/documents/document_vault_screen.dart';
import '../../screens/analytics/analytics_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/search/global_search_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/navigation/navigation_screen.dart';
import '../../features/payment_scanner/screens/payment_scanner_screen.dart';
import '../../features/payment_scanner/screens/auto_payment_dashboard_screen.dart';
import '../../features/ai_assistant/screens/ai_assistant_screen.dart';
import '../../features/health/presentation/pages/health_dashboard_page.dart';
import '../../features/health/presentation/pages/health_profile_page.dart';
import '../../features/health/presentation/pages/health_progress_page.dart';
import '../../features/health/presentation/pages/food_search_page.dart';
import '../../features/health/presentation/pages/custom_food_page.dart';
import '../../features/health/presentation/pages/step_counter_page.dart';
import '../../features/health/presentation/pages/water_tracker_page.dart';
import '../../features/health/presentation/pages/weight_tracker_page.dart';
import '../../features/health/presentation/pages/food_history_page.dart';
import '../../navigation/main_navigation.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final isLocked = ref.watch(authLockProvider);

  return GoRouter(
    initialLocation: isLocked ? '/lock' : '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainNavigation(child: child);
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/my_day',
            builder: (context, state) => const MyDayScreen(),
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
          ),
          GoRoute(
            path: '/todos',
            builder: (context, state) => const TodosScreen(),
          ),
          GoRoute(
            path: '/health',
            builder: (context, state) => const HealthDashboardPage(),
          ),
          GoRoute(
            path: '/navigation',
            builder: (context, state) => const NavigationScreen(),
          ),
          GoRoute(
            path: '/bills',
            builder: (context, state) => const BillsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/health_profile',
        builder: (context, state) => const HealthProfilePage(),
      ),
      GoRoute(
        path: '/health_progress',
        builder: (context, state) => const HealthProgressPage(),
      ),
      GoRoute(
        path: '/food_search',
        builder: (context, state) => const FoodSearchPage(),
      ),
      GoRoute(
        path: '/custom_food',
        builder: (context, state) => const CustomFoodPage(),
      ),
      GoRoute(
        path: '/step_counter',
        builder: (context, state) => const StepCounterPage(),
      ),
      GoRoute(
        path: '/water_tracker',
        builder: (context, state) => const WaterTrackerPage(),
      ),
      GoRoute(
        path: '/weight_tracker',
        builder: (context, state) => const WeightTrackerPage(),
      ),
      GoRoute(
        path: '/food_history',
        builder: (context, state) => const FoodHistoryPage(),
      ),
      GoRoute(
        path: '/payment_scanner',
        builder: (context, state) => const PaymentScannerScreen(),
      ),
      GoRoute(
        path: '/auto_payment',
        builder: (context, state) => const AutoPaymentDashboardScreen(),
      ),
      GoRoute(
        path: '/ai_assistant',
        builder: (context, state) => const AiAssistantScreen(),
      ),
      GoRoute(
        path: '/income',
        builder: (context, state) => const IncomeScreen(),
      ),
      GoRoute(
        path: '/budget',
        builder: (context, state) => const BudgetScreen(),
      ),
      GoRoute(
        path: '/savings',
        builder: (context, state) => const SavingsScreen(),
      ),
      GoRoute(
        path: '/loans',
        builder: (context, state) => const LoansScreen(),
      ),
      GoRoute(
        path: '/borrowed',
        builder: (context, state) => const BorrowedMoneyScreen(),
      ),
      GoRoute(
        path: '/net_worth',
        builder: (context, state) => const NetWorthScreen(),
      ),
      GoRoute(
        path: '/habits',
        builder: (context, state) => const HabitsScreen(),
      ),
      GoRoute(
        path: '/reminders',
        builder: (context, state) => const RemindersScreen(),
      ),
      GoRoute(
        path: '/notes',
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) => const JournalScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/travel',
        builder: (context, state) => const TravelScreen(),
      ),
      GoRoute(
        path: '/group_expenses',
        builder: (context, state) => const GroupExpensesScreen(),
      ),
      GoRoute(
        path: '/health_score',
        builder: (context, state) => const HealthScoreScreen(),
      ),
      GoRoute(
        path: '/customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryScreen(),
      ),
      GoRoute(
        path: '/vault',
        builder: (context, state) => const DocumentVaultScreen(),
      ),
      GoRoute(
        path: '/analytics',
        builder: (context, state) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
    ],
  );
});
