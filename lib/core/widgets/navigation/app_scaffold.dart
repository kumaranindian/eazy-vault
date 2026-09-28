import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';
import 'bottom_nav_bar.dart';
import 'navigation_rail_sidebar.dart';

/// Wraps the dashboard/transactions/accounts/categories routes with a
/// bottom nav bar (mobile), a collapsed rail (tablet) or an extended rail
/// (desktop). Used as a [ShellRoute] builder, so [location] always reflects
/// the current one of those four routes.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  static const List<String> _routes = [
    RouteConstants.dashboard,
    RouteConstants.transactions,
    RouteConstants.accounts,
    RouteConstants.categories,
  ];

  static const List<NavigationDestination> _destinations = [
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

  int get _selectedIndex {
    final index = _routes.indexOf(location);
    return index == -1 ? 0 : index;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Mobile: < 600px - Bottom Navigation
        if (width < 600) {
          return Scaffold(
            body: child,
            bottomNavigationBar: BottomNavBar(
              destinations: _destinations,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) =>
                  _onDestinationSelected(context, index),
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
                  onDestinationSelected: (index) =>
                      _onDestinationSelected(context, index),
                  extended: false,
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: child),
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
                onDestinationSelected: (index) =>
                    _onDestinationSelected(context, index),
                extended: true,
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}
