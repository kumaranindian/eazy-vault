import 'package:flutter/material.dart';

import '../../constants/app_spacing.dart';
import 'bottom_nav_bar.dart';
import 'navigation_rail_sidebar.dart';

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Dashboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Transactions',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      selectedIcon: Icon(Icons.account_balance_wallet),
      label: 'Accounts',
    ),
    NavigationDestination(
      icon: Icon(Icons.category_outlined),
      selectedIcon: Icon(Icons.category),
      label: 'Categories',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Mobile: < 600px - Bottom Navigation
        if (width < 600) {
          return Scaffold(
            body: widget.child,
            bottomNavigationBar: BottomNavBar(
              destinations: _destinations,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
            ),
          );
        }

        // Tablet: 600-1024px - Navigation Rail
        if (width < 1024) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRailSidebar(
                  destinations: _destinations,
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  extended: false,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: widget.child),
              ],
            ),
          );
        }

        // Desktop: > 1024px - Extended Navigation Rail / Sidebar
        return Scaffold(
          body: Row(
            children: [
              NavigationRailSidebar(
                destinations: _destinations,
                selectedIndex: _selectedIndex,
                onDestinationSelected: _onDestinationSelected,
                extended: true,
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: widget.child),
            ],
          ),
        );
      },
    );
  }
}
