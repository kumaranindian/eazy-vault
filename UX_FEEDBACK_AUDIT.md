# UX Feedback Audit — Loading, Toast & Confirmation Coverage

Scope: every async user action touched by Phase 1, plus a sweep of pre-existing screens for the
same gaps. "Status" is one of: **Fixed** (this phase added missing feedback), **New** (brand-new
feature, built with full feedback from the start), **Already good** (spot-checked, no change
needed), **Deferred** (a real gap, intentionally left — see note).

Centralized utilities reused everywhere below (no competing framework introduced):
`ContextExtensions.showSuccessSnackBar`/`showErrorSnackBar`/`showInfoSnackBar`
(`lib/core/extensions/context_extensions.dart`), `ConfirmationDialog`
(`lib/core/widgets/confirmation_dialog.dart`), `LoadingIndicator`/`ButtonProgress`
(`lib/core/widgets/loading_indicator.dart`), `EmptyState`, `ErrorView`.

## Phase 1 features

| Screen | Action | Current Feedback (before) | Required Feedback | Status |
|---|---|---|---|---|
| Transaction detail (modal + page) | View Attachment | Silent no-op / plain text, no link at all | Validated open in new tab, error snackbar on bad/unreachable URL | Fixed |
| Profile page | Save display name | N/A (page didn't exist) | Validate → `ButtonProgress` → success/error snackbar | New |
| Profile page | Toggle notifications | N/A | Disabled switch while toggling → success/error/info snackbar reflecting browser permission state | New |
| Categories (page + dashboard modal) | Delete category | No delete action existed | Confirmation → per-card spinner → success/error snackbar (surfaces "category in use" as a plain message) | New |
| Recurring rule | Create (with past-due occurrences) | Generic "created successfully", catch-up silently deferred to next session | "Recurring rule created. N missed transactions were added." when any were generated | Fixed |
| Recurring rule | Delete | Hand-rolled `AlertDialog`, no shared styling | `ConfirmationDialog` (destructive) → success/error snackbar | Fixed |
| Budget notifications | Threshold crossed (80/90/100%) | N/A | Browser notification (if enabled+permitted) + always-visible in-app bell entry | New |
| Loan/bill notifications | Due in 3 days / tomorrow / today / overdue | N/A (dashboard widget showed it passively, no alerting) | Same as above | New |
| Dashboard | Net worth chart load | N/A | Loading spinner → chart or `ErrorView`-style retry → empty state for no history | New |
| Transactions page / dashboard | Import CSV | N/A | "Analyzing CSV..." → mapping form → preview with Total/Valid/Invalid/Duplicate counts → "Importing X of Y transactions" → final summary ("Import completed. N imported, N skipped as duplicates, N invalid.") | New |
| Transaction detail | Add attachment | Manual URL paste only, no upload | File picker → "Uploading N%" progress → success/error snackbar, retry by re-picking | New |
| Transaction detail | Remove attachment | N/A | Confirmation → per-row spinner → success/error snackbar | New |

## Pre-existing screens — retrofit pass

| Screen | Action | Current Feedback (before) | Required Feedback | Status |
|---|---|---|---|---|
| Budgets modal | Delete budget | Hand-rolled `AlertDialog` (no destructive-red styling) | `ConfirmationDialog` | Fixed |
| Transaction detail modal | Delete transaction | Hand-rolled `AlertDialog` | `ConfirmationDialog` | Fixed |
| Dashboard (quick-add dialog delete) | Delete transaction | Hand-rolled `AlertDialog` | `ConfirmationDialog` | Fixed |
| Transactions modal (filter dialog delete) | Delete transaction | Hand-rolled `AlertDialog` | `ConfirmationDialog` | Fixed |
| App bar / nav rail | Sign out | Confirmation existed; no loading state; a failure was silently swallowed | Spinner + disabled while signing out; error snackbar on failure | Fixed |
| Login / Register / Forgot Password | Submit | Already had `_isLoading` → `ButtonProgress` ("Signing in...", "Sending...") → success/error snackbar, fields disabled while loading | — | Already good |
| Accounts / Categories add-edit pages | Save | Already had `_isLoading` → `ButtonProgress` → success/error snackbar | — | Already good |
| Account detail | Delete account | Already used `ConfirmationDialog` + notifier call + snackbar | — | Already good |
| Transaction detail page | Delete transaction | Already used `ConfirmationDialog` | — | Already good |
| Categories page | Load default categories | Already had `_isSeeding` guard + snackbar | — | Already good |

## Deferred (known, intentional gaps)

- CSV import's duplicate check queries up to 1000 existing transactions per import; an account with
  more than that in the statement's date range wouldn't get a "loading more" indicator for the
  check itself (the check would simply run against a partial set). Noted in
  `PHASE_1_IMPLEMENTATION_PLAN.md`'s Known Limitations — not expected at personal-finance scale.
- No widget/integration tests were added for the new UI flows; coverage is at the service/logic
  layer (see `PHASE_1_IMPLEMENTATION_PLAN.md` → Tests added), matching this repo's existing
  unit-test-heavy style. Manual verification: analyzer (0 errors) + full test suite green after
  every commit + `flutter build web --release` smoke test for the web/`dart:html`-touching features
  (notifications, CSV import, attachments). Interactive browser click-through could not be performed
  in this environment — see `PHASE_1_PRODUCTION_READINESS.md` for what that means for sign-off.

## Verification performed

- `flutter analyze`: 0 errors after every commit (pre-existing warning/info backlog untouched).
- `flutter test`: grew from the pre-existing suite to 108 passing tests, 0 failures, after every
  commit.
- `flutter build web --release`: succeeded after the notifications, CSV import and attachments
  commits (the three that exercise `dart:html`/web-only plugin code paths).
- No asynchronous operation in the new/changed code leaves a permanent spinner: every `_isLoading`/
  `_isUploading`/`_isDeleting`/`_isTogglingNotifications` flag is cleared in both the success and
  failure paths (checked file-by-file while writing each feature).
