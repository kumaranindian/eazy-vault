enum AlertSeverity { info, warning, critical }

/// A budget-threshold or bill-due alert, shown in the in-app notification
/// bell and (if enabled and permitted) as a browser notification.
class AppAlert {
  const AppAlert({
    required this.key,
    required this.title,
    required this.body,
    required this.severity,
  });

  /// Stable dedup key (e.g. `budget:<id>:<2026-03>:90`). Browser notifications
  /// fire at most once per key; the in-app bell always shows every alert
  /// current conditions produce, regardless of what's already been notified.
  final String key;
  final String title;
  final String body;
  final AlertSeverity severity;
}
