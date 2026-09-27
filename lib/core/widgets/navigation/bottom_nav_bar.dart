import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_constants.dart';

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const List<String> _routes = [
    RouteConstants.dashboard,
    RouteConstants.transactions,
    RouteConstants.accounts,
    RouteConstants.categories,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        onDestinationSelected(index);
        context.go(_routes[index]);
      },
      destinations: destinations,
      animationDuration: const Duration(milliseconds: 300),
    );
  }
}
