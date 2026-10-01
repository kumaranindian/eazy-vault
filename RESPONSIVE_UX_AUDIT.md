# Responsive UI & UX Stability Audit

Date: 2026-09-29 · Branch: `feature/claude-verification`

Scope: application-wide responsiveness (phone portrait/landscape, tablet, desktop, mobile "desktop site"), dark theme, loading states, success/error feedback, form validation. Business logic, balance math, Firestore schema, rules and routes are unchanged.

**Not verified:** the layouts were not checked visually in a browser at the target viewport sizes (no running Firebase session was available here). All fixes were made from code inspection and checked with `flutter analyze`, the test suite and a release web build. Section 13 lists what still needs a manual pass.

---

## 1. Problems identified

| # | Problem | Where |
|---|---|---|
| P1 | White backgrounds on phones | App-wide |
| P2 | White flash before Flutter paints / around the canvas on resize | `web/index.html` |
| P3 | Error screen always light and showing raw exception text | `ErrorBoundary` |
| P4 | Dialogs sized from `MediaQuery` percentages **plus** an `AlertDialog` title → taller than the screen, overflow in landscape | Accounts, Categories, Transactions modals |
| P5 | Filters and list fixed in one `Column`; in landscape the list got zero height | `TransactionsModal` |
| P6 | Tabbed add-transaction modal: `Expanded` inside an unbounded `Column` (layout exception) and a height of 60% of the screen inside a dialog | `AddTransactionTabbedModal`, `AddTransactionDialog(showDialog: false)` |
| P7 | Transfer form didn't scroll → overflow in landscape / with the keyboard open | `TransferTransactionForm` |
| P8 | Transaction detail content not `Flexible` → never scrolled; 3 action buttons overflowed on phones | `TransactionDetailModal` |
| P9 | Fixed `childAspectRatio: 2.5` grid clipped account cards on tablets and made them huge on desktop | `AccountsPage` |
| P10 | Content stretched edge-to-edge on wide monitors | Dashboard, list/detail/form pages |
| P11 | Rows overflowing at 320–360px: remember-me row, account summary chips, summary dialog rows, amounts in cards, dropdown items with long names, loan summary amounts | Several |
| P12 | Color/icon pickers used `width: double.maxFinite` → giant swatches on desktop | Picker dialogs |
| P13 | Raw exception text shown to users (`'Failed to fetch accounts: FirebaseException …'`) | All data sources, repositories, 3 forms |
| P14 | Silent failures / missing error UI (loan totals, recent transactions, loans list button, edit modal load) | Dashboard, modals |
| P15 | Edit pages showed the blank "Add" form while loading; saving early would **create a duplicate** instead of updating; a failed load left the blank form | Add/edit account, category, transaction pages; edit modal |
| P16 | `setState` called during `build` | `CategoriesModal` |
| P17 | Swipe-to-delete asked twice; cancelling the second prompt crashes ("dismissed Dismissible still in tree"). On the Transactions page the card menu deleted **without** confirmation | `TransactionCard`, `TransactionsPage` |
| P18 | Duplicate-submit / no progress on: seed default categories, sync balances, delete from detail modal, add/save buttons without spinners | Several |
| P19 | Transactions modal never loaded page 2 (`hasMore` ignored) | `TransactionsModal` |
| P20 | Splash: two fixed 200×200 images + large gaps (~670px) overflowed landscape phones | `SplashScreen` |
| P21 | PWA manifest locked orientation to portrait; blue splash colour | `web/manifest.json` |

## 2. Root causes

- **P1 – white backgrounds:** `MaterialApp` used `ThemeMode.system`. Phones in light mode got the full light theme (`#FAFAFA` scaffold, white surfaces). There was no per-screen bug. The fix is global: `ThemeMode.dark`. The light theme is kept in code but is no longer used.
- **P2:** `<body>` had no background, so the browser default (white) showed until the canvas painted, and during address-bar/rotation resizes.
- **P3:** `ErrorBoundary` builds its own `MaterialApp` without a theme and read `Theme.of` from the outer context.
- **P4–P6, P8:** dialogs took their height from `MediaQuery` percentages that ignored the dialog's own title, insets and keyboard, so height was over-constrained. The consistent fix is `Dialog` + a max width + one flexible scroll area (see §4).
- **P13:** data sources built messages with `'Failed to …: ${e.toString()}'` and repositories passed `e.toString()` into `Failure.unknownError`.
- **P17:** `TransactionCard` confirmed inside `Dismissible.confirmDismiss`, but every caller also confirmed (or, on the Transactions page, didn't confirm from the menu).

Orientation and resizing: no code stored screen sizes in state. The rotation problems came from the fixed heights and percentage sizing above. All new sizing reads constraints or `MediaQuery.sizeOf` during `build`, so it re-lays out on every resize or rotation.

## 3. Files changed

**New shared code**
- `lib/core/utils/error_messages.dart`: `ErrorMessages.from(error, action:)` maps Firebase codes, timeouts and network errors to user messages.
- `lib/core/widgets/responsive_layout.dart`: `ResponsiveContent` (centered, width-capped) and `ResponsiveGrid` (column count from the available width).
- `lib/core/widgets/form_dialog.dart`: dialog shell for scrolling forms.
- `lib/core/widgets/list_dialog.dart`: tall list dialog (header, flexible body, wrapping actions).
- `lib/core/widgets/branded_dialog_title.dart`: the EazyVault header used on dialogs; hidden on short viewports.

**Core:** `main.dart`, `core/theme/app_theme.dart`, `core/constants/breakpoints.dart`, `core/extensions/context_extensions.dart`, `core/utils/validators.dart`, `core/widgets/{error_boundary,splash_screen,loading_indicator,error_view,empty_state,confirmation_dialog}.dart`.

**Web:** `web/index.html`, `web/manifest.json`.

**Features (UI):** dashboard page, header, breakdown chart, spending trends, loans summary, upcoming bills, add-transaction dialog + tabbed modal; transactions page, detail page, add/edit page, card, modal, detail modal, edit modal, transfer / loan / repayment forms; accounts page, detail page, add/edit page, card, modal, add modal, color/icon pickers, sync balances action; categories page, modal, add modal, add/edit page; login / register / forgot-password pages, auth layout, Google button.

**Features (data layer, message text only):** `*_remote_datasource.dart`, `*_repository_impl.dart`, `account_balance_service.dart`, `transfer_service.dart`, `loan_service.dart`. Only the exception **message** changed. Control flow, balance math and Firestore writes are untouched.

## 4. Responsive improvements

Breakpoints (`Breakpoints`): mobile < 600, tablet 600–1024, desktop ≥ 1024. New: `compactHeight` < 500 (landscape phones, phones in desktop-site mode), `contentMaxWidth` 1200, `formMaxWidth` 560, `listDialogMaxWidth` 900.

Patterns applied:
- **Constraint-based, not device-based.** `ResponsiveGrid` and the summary cards use `LayoutBuilder` constraints, so they adapt to the real available width, including desktop-site mode on a phone.
- **Dashboard:** content capped at 1200px. Quick actions grid is 2 columns on phones and 7 in one row on desktop. Income / Expense / Net show 3 across at ≥ 600px. Loans and Upcoming Bills sit side by side on wide screens. The footer is pinned only when the viewport is at least 500px tall; otherwise it scrolls with the content. The user name in the AppBar is hidden on phones.
- **Dialogs:** `Dialog` with a max width and one scroll area. `Dialog` already subtracts the on-screen keyboard, so fields and buttons stay reachable. Theme `insetPadding` is 16px horizontal (Material's 40px left 240px for content on 320px phones). The branded header is dropped on short viewports.
- **Lists:** the transactions modal puts its filters and the list in one `CustomScrollView`, lays out its filters with `ResponsiveGrid`, and loads the next page on scroll. The Transactions, Categories and detail pages are centered and width-capped, with space left for the FAB.
- **Charts:** the account breakdown fills the card width and only scrolls horizontally (inside the chart) when there are more accounts than fit. The spending trend is 200px tall on phones and 260px on larger screens.
- **Tables:** none exist. Lists are card lists, so no table work was needed.

## 5. Dark theme fixes

- `ThemeMode.dark` app-wide.
- `web/index.html`: `html, body { background: #121212 }` (= `AppColors.backgroundDark`), plus `theme-color` and `color-scheme: dark` meta tags. Manifest background and theme colour set to `#121212`.
- Dark `ThemeData` completed: explicit `surfaceContainer*` roles, `canvasColor`, and themes for bottom sheet, popup menu, drawer, navigation bar, date/time pickers, dropdown menu, tooltip and progress indicator. Date pickers and menus no longer derive surfaces from Material defaults.
- `ErrorBoundary` uses `AppTheme.darkTheme`. The splash uses the scaffold background.
- Hard-coded light colours replaced: `Colors.grey[300]` progress track, `Colors.grey[600]` text, and the red error subtitle now use `colorScheme` roles.

## 6. Loading-state improvements

- New `ButtonProgress` (spinner + "Saving…" / "Signing in…" etc.) used on submit buttons; each button is disabled while its action runs.
- Add account/category modals show the spinner on whichever of "Save" or "Save and add another" was pressed.
- **Sync balances:** a blocking progress dialog prevents repeat taps. **Seed categories:** guarded against double taps, with a spinner.
- **Delete from the detail modal:** "Deleting…" state, and the other actions are disabled meanwhile.
- **Edit pages/modal:** a loading indicator until the record is loaded, then the form. Save is disabled until then.
- Every `setState(_isLoading = true)` path resets on success, on failure, and on thrown exceptions (the add/edit transaction dialogs now catch exceptions around the notifier call).

## 7. Success-message improvements

- `showSnackBar` now replaces the current snackbar instead of queueing, is 480px wide on tablets/desktops, and sets text colours for contrast (the green success background with light text was about 2.5:1).
- Added "Signed in successfully" on login and Google sign-in.
- Existing specific messages kept ("Transfer completed successfully", "Account created successfully", …).

## 8. Error-handling improvements

- `ErrorMessages.from` examples:
  - `permission-denied` → "You don't have permission to perform this action."
  - `unavailable` / network → "Unable to connect to the server. Please check your internet connection and try again."
  - Unknown errors → "Couldn't load accounts. Please try again."
  - `AppException` messages pass through unchanged.
  - Raw errors are still logged via `LoggerService`.
- Auth: added `invalid-credential`, popup-closed and popup-blocked messages.
- Raw `error.toString()` removed from the account and transaction detail pages. They now use `ErrorView` with **Retry**.
- Retry added to failed monthly stats, recent transactions, spending trends and the transaction detail modal. Loan totals show "unavailable" instead of disappearing.
- `ErrorBoundary` hides technical details in release builds.

## 9. Form-validation improvements

- All money fields use `Validators.positiveAmount`, which enforces the max amount; transfer and loan forms previously had custom checks without it.
- Transfer: the destination can't equal the source (shown at the field).
- Loan:
  - The party name uses the name rules (2–50 chars).
  - The optional contact accepts a phone number or email (`Validators.optionalContact`); the keyboard switched from phone to text so "@" can be typed.
  - The due date must be on or after the loan date. Moving the loan date past the due date clears the due date.
- Add account/category: duplicate names are rejected locally. For categories the check is per type (income/expense).
- Vendor fields use `Validators.vendorName`.

## 10. Mobile-specific fixes

- 320px: the remember-me row and the "Don't have an account?" rows now wrap, and the Google button label ellipsizes.
- Account summary chips use a responsive grid; before, every chip was full-width.
- Amounts in transaction and account cards and in the balance header shrink to fit (`FittedBox`) instead of squeezing names.
- Landscape: the splash scales and scrolls, the auth layout is compact, the dashboard footer scrolls away, and dialogs drop the brand header.
- `ErrorView`/`EmptyState` use smaller illustrations on short screens.
- Swipe-to-delete is fixed (P17) and asks for confirmation exactly once on every screen.
- The PWA manifest allows any orientation.

## 11. Desktop-specific fixes

- Width caps (dashboard 1200, lists 900, detail 800, forms 560); color/icon pickers are 360px wide.
- The accounts page uses a natural-height grid (up to 3 columns).
- The dashboard uses multi-column sections.
- The transactions modal shows filters in up to 3 columns.
- Dialog actions wrap via `OverflowBar` instead of a `Row`.

## 12. Tests / static analysis executed

| Command | Result |
|---|---|
| `flutter analyze` | **0 errors** (baseline 0). Warnings **158** (baseline 184). The extra issues in the total are `always_use_package_imports` infos from new files, which follow the repo's relative-import style. |
| `flutter test` | **54 / 54 passed.** The transfer widget test caught a real bug during this work (a SnackBar `width` without floating behavior), which is fixed. |
| `flutter build web --release` | Succeeds. |

## 13. Remaining known issues

- **Needs a manual pass:**
  - Check the viewport matrix (320×568 … 1920×1080, portrait/landscape, desktop-site mode) in Chrome DevTools and on a real phone.
  - Watch in particular: the dashboard at 600–700px (grid breakpoints), the transactions modal with the keyboard open, and long account/category names.
- The light theme is still defined but unused. If a theme toggle is wanted later, the `theme_mode` prefs key already exists.
- Responsive navigation shell (`AppScaffold`, `BottomNavBar`, `NavigationRailSidebar`):
  - It is still unused. The app's navigation model is dashboard-as-hub with dialogs, and I kept that.
  - Adopting the shell would change the UX and needs a product decision.
- The attachment link in the transaction detail modal does nothing; `url_launcher` is declared but not wired up (pre-existing).
- The account and transaction detail pages' delete (app-bar menu) has no in-progress state; the operation is short but a second tap is possible.
- Most `withOpacity` and deprecated `Color.value` warnings are pre-existing and were left alone (lint backlog, CLAUDE.md §18).
- There is no web crash reporter (unchanged; PROJECT_AUDIT Q-8).

## 14. Recommended future improvements

1. Add golden or widget tests for the dashboard, transactions modal and auth pages at 320×568, 568×320, 768×1024 and 1440×900, so overflow regressions fail CI.
2. Replace the remaining `showDialog` calls that lack type arguments (analyzer warnings) and migrate `withOpacity` → `withValues`.
3. Decide on the navigation shell (§13) and, if adopted, route Accounts/Transactions/Categories through it with a `NavigationRail` on desktop and a `NavigationBar` on phones.
4. Pass the `ErrorMessages` action into `ErrorView` titles for more specific page-level errors.
5. Add a web-capable crash reporter so errors hidden from users in release still reach developers.
