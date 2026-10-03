# Phase 1 Production Readiness

> Honesty note on "Responsive": this environment has no interactive browser, so new screens below
> were built using the app's existing responsive conventions (`ResponsiveContent`, `ResponsiveGrid`,
> `Breakpoints`, `Wrap`/`ChoiceChip` for narrow widths, mobile full-screen `Dialog` variants where the
> existing pattern does that) and were **not** visually confirmed at mobile/tablet/desktop widths in
> a running browser. Pre-existing screens marked "Yes" were already shipped and are unchanged in
> layout. Treat new-screen "By convention" rows as needing a manual pass in Chrome before shipping.

| Feature | Implemented | Tested | Responsive | Error Handling | Security | Production Ready |
|---|---|---|---|---|---|---|
| Fix View Attachment | Yes | Manual code review; no dedicated test (trivial logic) | By convention | Invalid/unreachable URL → error snackbar, no crash | No new surface — reads an existing user-owned field | Yes |
| Settings/Profile page | Yes | Manual code review | By convention | Session-expired / save failure → error snackbar | Owner-scoped by existing `users/{uid}` rule; email immutable to avoid a half-built reauth flow | Yes, with the documented email-read-only limitation |
| Category delete UI | Yes | `categories_remote_datasource_test.dart` (in-use guard + soft-delete) | By convention | "In use" validation surfaces as plain message, not a stack trace | Soft-delete only (rules deny hard delete); guard prevents orphaning transaction references | Yes |
| Recurring catch-up on create | Yes | `recurring_transactions_notifier_test.dart` (4 missed occurrences generated + balance effect) | N/A (no new UI, existing modal) | Catch-up failure is logged; rule creation itself still reports its own success/failure | Writes go through the existing `AccountBalanceService`-backed path only | Yes |
| Budget & bill notifications | Yes | `alert_evaluator_test.dart` (threshold tiers, dedup keys, bill buckets) | By convention | Permission denied/unsupported → clear in-UI message, bell still works | Browser permission is opt-in; no data leaves the device (no push server) | Yes, with the documented web-only (no closed-tab push) limitation |
| Net worth history | Yes | `net_worth_calculator_test.dart` (bucketing math) + `net_worth_service_test.dart` (end-to-end, transfer-nets-to-zero) | By convention | Load failure → retry button; empty history → empty state | Read-only, reuses existing owner-scoped repositories | Yes |
| CSV transaction import | Yes | `csv_import_service_test.dart` (11 cases: dates, amounts, debit/credit, duplicates, import outcome) | By convention | Invalid file / unreadable file / per-row invalid reasons / per-row import failures all surfaced, never a raw exception | Imports go through the existing per-user `createTransaction` path; no direct Firestore writes | Yes, with the documented duplicate-check window limitation |
| Receipt/photo attachments | Yes | `account_balance_service_test.dart` → `updateAttachments` group (zero balance effect on every type, including non-editable ones) | By convention | Oversized/wrong-type file rejected client-side (mirrors `storage.rules`); upload failure → error snackbar with retry | Uses the existing owner-scoped, size/type-validated Storage path; `storage.rules` unchanged | Yes |
| Global UX retrofit | Yes | Full regression suite (108 tests) green after the change | N/A | — | — | Yes |

## Known limitations

- **Web-only notifications**: the browser Notification API only fires while a tab is open. No
  background push (would require a service worker + FCM for Web — explicitly not added, since the
  spec says not to introduce new infrastructure unless required, and the in-app bell covers the
  "must work gracefully" requirement).
- **CSV import**: an unsigned amount column with no debit/credit columns and no mapped type column
  is left invalid rather than guessed (ambiguous direction). Duplicate detection queries up to 1000
  existing transactions for the target account/date-range.
- **Net worth "fiscal year"**: treated as a trailing 12 calendar months; no fiscal-year
  configuration exists elsewhere in the app to anchor a different year-start.
- **Profile email**: read-only in this phase.

## Platform limitations

- Flutter **Web only** (confirmed: no `android`/`ios` directories in the repo). Every new feature
  was built against that constraint — no mobile-only APIs were introduced.
- Browser Notification permission behavior (and whether notifications are shown at all) varies by
  browser and OS; the in-app bell is the one guaranteed-to-work surface.

## Required Firebase changes

None. See `PHASE_1_FIREBASE_CHANGES.md` for the full per-feature analysis.

## Required dependencies

`csv: ^6.0.0` (new). `file_picker`, `firebase_storage`, `url_launcher` were already declared and are
now actually used. Run `flutter pub get` after pulling this work.

## Required configuration

None beyond what already exists (`lib/firebase_options.dart` generated locally, gitignored, per
existing project convention). No new environment variables, flavors, or `--dart-define` values.

## Migration requirements

None. No Firestore schema changed; no backfill needed. Existing transactions without `attachments`
continue to work (the field is already nullable and was already in the model).

## Future improvements (not implemented, not requested)

- Widget/integration tests for the new wizards (CSV import) and charts (net worth) — current
  coverage is at the service/logic layer, consistent with this repo's existing test style.
- A real push channel (Firebase Cloud Messaging for Web + service worker) if background notification
  delivery becomes a hard requirement.
- Removing the still-unused `image_picker` dependency in a separate, explicitly-scoped cleanup.
- Pagination in the CSV duplicate-check query if real users start importing statements covering
  accounts with very large transaction histories in the overlapping date range.
