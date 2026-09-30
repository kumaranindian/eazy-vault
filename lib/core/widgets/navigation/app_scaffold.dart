import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import 'bottom_nav_bar.dart';
import 'navigation_rail_sidebar.dart';

/// Persistent responsive chrome for the four top-level destinations
/// (Dashboard/Transactions/Accounts/Categories), wired in via a `ShellRoute`
/// in `app_router.dart`. The selected tab is derived from [currentPath]
/// (the current route) rather than kept as local state, so it stays correct
/// across deep links and browser back/forward.
///
/// The breakpoint branch below switches between entirely different chrome
/// widgets (`BottomNavBar` / collapsed `NavigationRailSidebar` / extended
/// `NavigationRailSidebar`), each with their own `MouseRegion`/`InkWell`
/// hover handling. That decision is read from [MediaQuery] in `build()`
/// deliberately, not from a `LayoutBuilder` in the layout phase: swapping a
/// hover-bearing subtree out from under the mouse tracker mid-layout (which
/// a `LayoutBuilder` rebuild can do while a pointer event is still being
/// processed, e.g. during a window resize) can retrigger Flutter's
/// `MouseTracker` while it's already updating devices. Driving the swap
/// from `MediaQuery.sizeOf` instead means it goes through the normal
/// build/dispose scheduling.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

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

  // Kept in the same order as `_destinations`; must match the order the
  // nav widgets navigate with (see NavigationRailSidebar/BottomNavBar).
  static const List<String> _routes = [
    RouteConstants.dashboard,
    RouteConstants.transactions,
    RouteConstants.accounts,
    RouteConstants.categories,
  ];

  int get _selectedIndex {
    final index = _routes.indexOf(currentPath);
    return index == -1 ? 0 : index;
  }

  // Match NavigationRail's own Material 3 `minWidth`/`minExtendedWidth`
  // defaults. NavigationRail sizes itself from its content rather than
  // occupying a width its parent hands it, so as a non-Expanded `Row` child
  // it otherwise gets an *unbounded* width — anything inside its `leading`/
  // `trailing` that needs a bounded ancestor (an `Expanded`, a `ListTile`)
  // throws a layout exception the moment it's actually rendered. Pinning it
  // to its own default width here gives it (and everything inside it) a
  // real bound without changing how wide it ends up looking.
  static const double _railWidth = 80;
  static const double _extendedRailWidth = 256;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final selectedIndex = _selectedIndex;

    // Mobile: < 600px - Bottom Navigation
    if (width < 600) {
      return Scaffold(
        body: child,
        bottomNavigationBar: BottomNavBar(
          destinations: _destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: (_) {},
        ),
      );
    }

    // Tablet: 600-1024px - Navigation Rail
    if (width < 1024) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: _railWidth,
              child: NavigationRailSidebar(
                destinations: _destinations,
                selectedIndex: selectedIndex,
                onDestinationSelected: (_) {},
                extended: false,
              ),
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
          SizedBox(
            width: _extendedRailWidth,
            child: NavigationRailSidebar(
              destinations: _destinations,
              selectedIndex: selectedIndex,
              onDestinationSelected: (_) {},
              extended: true,
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
