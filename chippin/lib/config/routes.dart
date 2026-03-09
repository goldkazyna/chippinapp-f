import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/new_bill_screen.dart';
import '../screens/participants_screen.dart';
import '../screens/add_items_screen.dart';
import '../screens/split_items_screen.dart';
import '../screens/paid_by_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/adjustments_screen.dart';
import '../screens/summary_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final needsOnboarding = ref.watch(needsOnboardingProvider);

  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => _ErrorDiagScreen(
      error: 'Route error: ${state.error}\nLocation: ${state.matchedLocation}\nPath: ${state.uri}',
    ),
    redirect: (context, state) {
      final isSplash = state.matchedLocation == '/';
      final isLoginRoute = state.matchedLocation == '/login';
      final isOnboardingRoute = state.matchedLocation == '/onboarding';

      // While checking saved token, stay on splash
      if (authState.isLoading) {
        return isSplash ? null : '/';
      }

      final isAuthenticated = authState.valueOrNull != null;

      // After auth check resolved, leave splash
      if (isSplash) {
        if (isAuthenticated && needsOnboarding) return '/onboarding';
        if (isAuthenticated) return '/home';
        return '/login';
      }

      if (!isAuthenticated && !isLoginRoute) {
        return '/login';
      }
      if (isAuthenticated && needsOnboarding && !isOnboardingRoute) {
        return '/onboarding';
      }
      if (isAuthenticated && !needsOnboarding && (isLoginRoute || isOnboardingRoute)) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          backgroundColor: Color(0xFF0A0A0F),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFF6CFFB3)),
          ),
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final location = state.matchedLocation;
          int index = 0;
          if (location.startsWith('/history')) index = 1;
          if (location.startsWith('/profile')) index = 2;

          return ShellScreen(
            currentIndex: index,
            onTabChanged: (i) {
              switch (i) {
                case 0:
                  context.go('/home');
                case 1:
                  context.go('/history');
                case 2:
                  context.go('/profile');
              }
            },
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/bills/new',
        builder: (context, state) => const NewBillScreen(),
      ),
      GoRoute(
        path: '/bills/:id/participants',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ParticipantsScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/bills/:id/items',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AddItemsScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/bills/:id/adjustments',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return AdjustmentsScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/bills/:id/split',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return SplitItemsScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/bills/:id/paid-by',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return PaidByScreen(billId: id);
        },
      ),
      GoRoute(
        path: '/bills/:id/summary',
        builder: (context, state) {
          try {
            final id = int.parse(state.pathParameters['id']!);
            return SummaryScreen(billId: id);
          } catch (e, st) {
            return _ErrorDiagScreen(error: 'Summary route crash:\n$e\n\n$st');
          }
        },
      ),
    ],
  );
});

class _ErrorDiagScreen extends StatelessWidget {
  final String error;
  const _ErrorDiagScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bug_report, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('DIAGNOSTIC', style: GoogleFonts.manrope(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red)),
              const SizedBox(height: 12),
              SelectableText(error, style: GoogleFonts.manrope(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).canPop() ? Navigator.of(context).pop() : null,
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
