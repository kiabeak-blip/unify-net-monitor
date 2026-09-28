// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/device_manager.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/windows_dashboard.dart';
import 'screens/license_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await NotificationService.requestPermissions();

  runApp(
    ChangeNotifierProvider(
      create: (_) => DeviceManager(),
      child: const NetworkMonitorApp(),
    ),
  );
}

class NetworkMonitorApp extends StatelessWidget {
  const NetworkMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Unify Net Monitor',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: Platform.isWindows
          ? const LicenseGate(child: WindowsDashboard())
          : const HomeScreen(),
    );
  }

  ThemeData _buildTheme() {
    const bg = Color(0xFF0A0E1A);
    const surface = Color(0xFF111827);
    const card = Color(0xFF1A2235);
    const accent = Color(0xFF00D4FF);
    const green = Color(0xFF00FF88);
    const red = Color(0xFFFF4466);

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: green,
        error: red,
        surface: surface,
        onPrimary: bg,
        onSecondary: bg,
        onSurface: Colors.white,
      ),
      cardTheme: const CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28),
        headlineMedium: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
        titleLarge: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge: TextStyle(color: Colors.white70, fontSize: 15),
        bodyMedium: TextStyle(color: Colors.white60, fontSize: 13),
        labelSmall: TextStyle(color: Colors.white38, fontSize: 11),
      ),
      useMaterial3: true,
    );
  }
}
