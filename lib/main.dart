import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'ui/featuers/landing/views/landing_view.dart';
import 'ui/featuers/vault/views/vault_view.dart';

void main() {
  runApp(const ProviderScope(child: CryptoTreasuryApp()));
}

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingView(),
      ),
      GoRoute(
        path: '/vault',
        name: 'vault',
        builder: (context, state) => const VaultView(),
      ),
    ],
  );
});

class CryptoTreasuryApp extends ConsumerWidget {
  const CryptoTreasuryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Crypto Treasury',
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      routerConfig: router,
    );
  }

  ThemeData _buildLightTheme() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF4E8DFF),
        secondary: const Color(0xFF00C2A8),
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F6FA),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF4E8DFF),
        secondary: const Color(0xFF00C2A8),
      ),
      scaffoldBackgroundColor: const Color(0xFF0A0E1C),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
