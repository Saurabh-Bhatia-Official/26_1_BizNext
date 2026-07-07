// lib/main.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/database/database_helper.dart';
import 'core/providers/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_shell.dart';
import 'core/constants/app_constants.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/business_selector_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/auth/screens/sync_mode_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase init skipped/unconfigured on this platform: $e");
  }

  // Initialize FFI for Windows/Linux desktop
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Pre-warm database to apply schema
  await DatabaseHelper.instance.database;

  // Load preferences
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConstants.prefSyncMode, 'offline');
  const initialSyncMode = 'offline';

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        syncModeProvider.overrideWith((ref) => SyncModeNotifier(initialSyncMode)),
      ],
      child: const BizNextApp(),
    ),
  );
}

class BizNextApp extends ConsumerWidget {
  const BizNextApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);
    final isSplashDone = ref.watch(splashCompleteProvider);

    return MaterialApp(
      title: 'BizNext',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: isSplashDone ? _getHome(authState) : const SplashScreen(),
    );
  }

  Widget _getHome(AuthState authState) {
    switch (authState.status) {
      case AuthStatus.loading:
        return const SplashScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.businessNotSelected:
        return const BusinessSelectorScreen();
      case AuthStatus.authenticated:
        return const AppShell();
    }
  }
}

// In case the provider was named differently in auth_provider.dart
final authStateProvider = Provider<AuthState>((ref) => ref.watch(authProvider));
