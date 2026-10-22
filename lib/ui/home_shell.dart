import 'package:flutter/material.dart';

import 'chart_page.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';
import 'signals_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = <Widget>[
    DashboardPage(),
    ChartPage(),
    SignalsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: _pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'داشبورد'),
          NavigationDestination(icon: Icon(Icons.candlestick_chart_outlined), label: 'نمودار'),
          NavigationDestination(icon: Icon(Icons.notifications_active_outlined), label: 'سیگنال‌ها'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'تنظیمات'),
        ],
      ),
    );
  }
}
