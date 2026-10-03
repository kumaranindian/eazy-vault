# Phase 1 Implementation Plan — EazyVault

> Written against the `Develop` branch. Unlike the other `*_SUMMARY.md`/`*_STATUS.md` files in this
> repo root (which `CLAUDE.md` correctly warns are unreliable historical notes), this file reflects
> what was actually implemented, verified by `flutter analyze` (0 errors) and `flutter test` (all
> passing) after every commit below.

## Scope

Eight features plus an app-wide loading/toast UX pass, specified in two linked documents the user
provided. Implemented in the required order, one commit per feature, per `AGENT.md`/`CLAUDE.md`'s
"keep changes focused" rule.

## Pre-implementation analysis (what already existed)

- **Attachments**: `TransactionModel.attachments` (`List<String>?`) existed; forms had a manual
  "Attachment URL" text field; both detail surfaces rendered a "View Attachment" link whose `onTap`
  was a literal no-op (`transaction_detail_modal.dart`) or not even a link at all
  (`transaction_detail_page.dart`). `image_picker`, `file_picker`, `firebase_storage`, `url_launcher`
  were declared in `pubspec.yaml` but unused anywhere in `lib/`. `storage.rules` already had the
  exact path (`transactions/{userId}/{transactionId}/{fileName}`, 5 MB cap, image/PDF only) an
  upload feature would need.
- **Settings/Profile**: `RouteConstants.settings`/`.profile` existed as dead constants; no pages, no
  routes registered, no "update profile" method anywhere in the auth stack.
- **Category delete**: `CategoriesNotifier.deleteCategory` existed and was wired to the repository,
  but no UI called it, and (unlike accounts) the data source had no "category still in use" guard.
- **Recurring catch-up**: `RecurringTransactionService.catchUp`/`catchUpAll` existed and worked
  correctly, but was only ever invoked from a `keepAlive` provider watched once by the dashboard —
  never after creating a rule.
- **Notifications**: nothing existed. The repo has no `android`/`ios` directories — Flutter Web only.
- **Net worth history**: nothing existed; no balance-snapshot collection. `AccountBalanceService
  .signedAmountFor` (public, static) and `TransactionsRepository.getAccountHistory` were the
  reusable primitives already powering account statements.
- **CSV import**: nothing existed (confirmed via repo-wide search). The existing CSV *export*
  (`TransactionExportService.buildCsv`) used a fixed EazyVault-shaped column layout, not helpful for
  arbitrary bank exports. No `csv` parsing package was declared.
- **Real attachments** (upload): see Attachments above — `storage.rules` ready, nothing wired.
- **Global UX**: `ContextExtensions.showSuccessSnackBar/showErrorSnackBar/showInfoSnackBar`,
  `ConfirmationDialog`, `LoadingIndicator`/`ButtonProgress`, `EmptyState`, `ErrorView` already existed
  and were used consistently in most add/edit forms (accounts, categories, transactions). Gaps found:
  `budgets_modal.dart`, `recurring_transactions_modal.dart`, and 3 of 4 transaction-delete call sites
  hand-rolled their own `AlertDialog` instead of the shared `ConfirmationDialog`; `SignOutButton` had
  no loading state and silently swallowed a sign-out failure.

## Conflicts between the spec and the real codebase, and how they were resolved

1. **Notifications — `flutter_local_notifications` doesn't fit a Web-only app.** Used the browser
   Notification API (`dart:html.Notification`) instead, gated behind a permission request, plus an
   always-on in-app bell so the feature works when permission is denied/unsupported/unsupported by
   the browser. No new dependency.
2. **Attachments vs. `AccountBalanceService.isEditableType`.** Transfers/loans/repayments can't go
   through `updateTransaction` (balance-math protection), but attaching a receipt doesn't move money
   and must work on any transaction type. Added one narrow `AccountBalanceService.updateAttachments`
   method that writes only the `attachments` field, no balance effect, no editable-type check.
3. **Category delete had no "in use" guard, unlike accounts.** Added the same guard
   `AccountsRemoteDataSourceImpl.deleteAccount` already has, mirrored onto
   `CategoriesRemoteDataSourceImpl.deleteCategory`.
4. **Net worth — no snapshot collection.** Reconstructed on the fly from `getAccountHistory` +
   `signedAmountFor`, per the spec's own stated preference order. Lives in `features/dashboard/`, not
   as a 9th report type (the reports feature's "don't duplicate balance math" rule is about
   `ReportCalculationService` specifically; this reuses the same underlying primitive without
   touching it).
5. **CSV import file picking.** Used the already-declared-but-unused `file_picker` (supports web)
   rather than hand-rolling a `dart:html` file input.
6. **Profile — email editing.** Left read-only in this phase; only `displayName` is editable, to
   avoid introducing a re-authentication flow nothing else in the app has.

## Order of implementation (commits, in order on `Develop`)

1. `feat: fix transaction attachment viewing`
2. `feat: add settings and profile page`
3. `feat: add category deletion UI`
4. `fix: catch up recurring transactions after rule creation`
5. `feat: add budget and bill notifications`
6. `feat: add net worth history`
7. `feat: add CSV transaction import`
8. `feat: add receipt and photo attachments`
9. `refactor: consolidate delete confirmations onto the shared dialog` (global UX retrofit pass)

After every commit: `dart run build_runner build --delete-conflicting-outputs` (when new
`@riverpod`/`@freezed` code was added) → `flutter analyze` (compared against the 0-error baseline) →
`flutter test` → `flutter build web --release` smoke test for features touching `dart:html`/web
plugins (notifications, CSV import, attachments).

## Files changed

57 files changed across the 9 commits (`git diff --stat` from before this work to `HEAD`). New
feature directories: `lib/features/notifications/`, `lib/features/csv_import/`,
`lib/features/dashboard/domain/{models,services}/net_worth_*`. Representative existing files
touched: `account_balance_service.dart` (+`updateAttachments`), `transactions_repository.dart`/`_impl.dart`
(+attachment methods), `categories_remote_datasource.dart` (+in-use guard),
`recurring_transactions_notifier.dart` (+catch-up-on-create), `app_router.dart`/`app_constants.dart`
(+routes), `dashboard_page.dart` (+net worth chart, notification bell, import quick action).

## Dependencies added

- `csv: ^6.0.0` — the only new dependency. Used solely for parsing arbitrary bank-statement CSVs
  (the hand-rolled export-side CSV writer wasn't reusable for parsing arbitrary input).
- `file_picker`, `firebase_storage`, `url_launcher` were already declared and unused — now wired up.
- `image_picker` remains unused (web file picker covers image selection; no camera use case).

## Firebase changes

**None.** See `PHASE_1_FIREBASE_CHANGES.md` for the full analysis — every new feature fits the
existing Firestore/Storage rules and index set.

## Tests added

- `test/unit/categories_remote_datasource_test.dart` — the new category "in use" delete guard.
- `test/unit/recurring_transactions_notifier_test.dart` — catch-up-on-create generates the right
  number of missed occurrences and updates balances.
- `test/unit/alert_evaluator_test.dart` — budget-threshold and bill-due-date alert logic (pure).
- `test/unit/net_worth_calculator_test.dart` + `net_worth_service_test.dart` — bucketing math (pure)
  and an end-to-end reconstruction (transfer nets to zero, income raises net worth).
- `test/unit/csv_import_service_test.dart` — date-format fallback, amount parsing (signed,
  debit/credit, currency symbols, type-column hint), duplicate detection, import outcome counts.
- Extended `test/unit/account_balance_service_test.dart` with an `updateAttachments` group proving
  zero balance effect on every transaction type, including non-editable ones (transfers).

All pre-existing tests continued to pass throughout (grew from the baseline count to 108).

## Known limitations

- Browser (Web Notification API) alerts only fire while a tab is open — there's no background/
  closed-tab push, since this is a web-only app with no service worker/FCM infrastructure added.
- CSV import's "unsigned amount column with no type-column hint" case can't disambiguate income vs.
  expense and is left invalid rather than guessed — users with that CSV shape should map a type
  column or use debit/credit columns instead.
- Net worth history's "fiscal year" range is treated as a trailing calendar year; no fiscal-year
  concept exists elsewhere in the app.
- Email address is read-only on the Profile page (by design — see Conflict #6 above).
- Duplicate detection in CSV import is signature-based (date + amount + description) and queries up
  to 1000 existing transactions for the account; a statement covering an unusually large existing
  history could exceed that without a pagination loop (not implemented, to avoid over-engineering
  for a personal-finance-scale app).

## Remaining work (not implemented, not requested)

- No automated widget/integration tests were added for the new UI flows (CSV import wizard, net
  worth chart, notification bell/settings) — covered by manual review and the underlying service/
  logic unit tests instead, consistent with the existing test suite's unit-test-heavy style.
- `image_picker` dependency could be removed from `pubspec.yaml` in a follow-up cleanup since it's
  still unused after this phase (left alone here to keep the diff minimal, per "don't remove things
  casually" guidance).
