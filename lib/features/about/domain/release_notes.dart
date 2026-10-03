/// One released version of the app, newest first in [releaseNotes].
class ReleaseNote {
  const ReleaseNote({
    required this.version,
    required this.date,
    required this.highlights,
  });

  /// Semver matching `AppConfig.appVersion` for the current release.
  final String version;

  /// Display date, e.g. 'October 2026'.
  final String date;

  /// User-facing bullets describing what shipped.
  final List<String> highlights;
}

const releaseNotes = <ReleaseNote>[
  ReleaseNote(
    version: '1.0.0',
    date: 'October 2026',
    highlights: [
      'Track income, expenses and transfers across all your accounts',
      'Lend and borrow money with loan tracking and repayments',
      'Monthly budgets per category with progress alerts',
      'Recurring transactions generated automatically',
      'Dashboard insights: spending trends, category breakdown, account balances',
      'Export transactions and reports to CSV, PDF and Excel',
      'Sign in with email/password or Google',
    ],
  ),
];
