import 'package:flutter/material.dart';
import 'info_screen.dart';
import 'lan_screen.dart';
import 'tools_screen.dart';
import 'about_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 1; // Start on LAN tab

  static const _screens = [
    InfoScreen(),
    LanScreen(),
    ToolsScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: primary.withOpacity(0.12),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _dest(Icons.info_outline, Icons.info, 'Info'),
            _dest(Icons.hub_outlined, Icons.hub, 'LAN'),
            _dest(Icons.build_outlined, Icons.build, 'Tools'),
            _dest(Icons.help_outline, Icons.help, 'About'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(IconData icon, IconData activeIcon, String label) {
    return NavigationDestination(
      icon: Icon(icon, color: Colors.white38),
      selectedIcon: Icon(activeIcon,
          color: Theme.of(context).colorScheme.primary),
      label: label,
    );
  }
}
