# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Facts here were re-verified against the source on 2026-10-03 (branch `ccr-3b33f961-q93u60`) — a full pass that found the codebase had moved well past the 2026-09-28 verification (new `about`, `onboarding`, `user_manual`, `notifications`, `budgets`, `recurring_transactions` and `csv_import` features; a live responsive nav shell; attachments with real file upload; dark-mode-only theming). The many `*_SUMMARY.md` / `*_STATUS.md` files in the repo root are historical AI-generated notes and are **not reliable** (e.g. `FINAL_COMPLETION_SUMMARY.md` claims "100% complete" and a passing test suite; neither is true). Trust the code and this file over them. `flutter analyze`/`flutter test` could not be re-run as part of this pass (no Flutter SDK in that environment) — the exact test count and analyzer-error count below are carried over unverified; treat them as stale until re-run.

---

## 1. Project Overview

- **What it is:** EazyVault ("Smart Finance Starts Here.") — a personal finance manager, Flutter **web** app backed by Firebase.
- **Purpose:** a single user tracks money across their own accounts: income, expenses, transfers between accounts, and money lent/borrowed (loans), with a dashboard summary.
- **Users/roles:** one role only — an authenticated individual who owns all their data. No admin, family sharing, or organizations exist.
- **Currency:** INR only, hard-coded (`AppConfig.defaultCurrency = '₹'`, `currencyCode = 'INR'`; formatting in `core/utils/currency_utils.dart`).
- **Status:** working app well past "prototype" — core CRUD plus budgets, recurring transactions, attachments, notifications, reports/export, onboarding and a real profile/settings page are all implemented and reachable (§20). The analyzer-error and test-pass/fail counts are unverified as of this pass (no Flutter SDK available) — don't assume either "0 errors, all passing" or "errors, tests don't compile" without re-running `flutter analyze`/`flutter test` yourself. See §16/§20.

### Business terminology
| Term | Meaning in code |
|---|---|
| Account | Money container (`AccountType`: `cash`, `savings`, `current`, `upi`, `creditCard`). Has `openingBalance` and a stored `currentBalance`. |
| Category | Label for income/expense (`CategoryType`: income/expense). `isDefault` marks seeded ones from `DefaultCategories`. |
| Transaction | Any money movement. `TransactionType`: `income`, `expense`, `transfer`, `loanGiven`, `loanTaken`, `loanRepayment`. |
| Vendor | Optional payee/payer name on a transaction; used as the loan counterparty name. |
| Transfer | Money moved between two of the user's accounts; `metadata` holds `TransferMetadata` (`fromAccountId`, `toAccountId`). |
| Loan | A `loanGiven`/`loanTaken` transaction whose `metadata` holds `LoanMetadata` (party, due date, `LoanStatus` pending/partial/completed/overdue, `remainingAmount`, installments). Repayments are `loanRepayment` transactions linking back via `linkedLoanId`. |

## 2. Technology Stack

| Area | Actual |
|---|---|
| Flutter / Dart | Created with Flutter **3.32.x stable** (`.metadata` revision `edada7c`); lockfile requires Dart `>=3.8.0`, Flutter `>=3.32.0`. `pubspec.yaml` says `sdk: >=3.3.0 <4.0.0`. |
| State management | `flutter_riverpod` 2.x + `riverpod_annotation`/`riverpod_generator` (code-generated `@riverpod`) |
| Routing | `go_router` 14 |
| Models | `freezed` + `json_serializable` |
| Backend | Firebase only — no custom API server |
| Firebase services used in code | Auth (email/password + Google), Cloud Firestore, Storage (`firebase_storage` — real attachment upload, see §10), Analytics (release only). Crashlytics is initialized in release but effectively inactive (see §13). |
| Charts | `fl_chart` |
| Formatting | `intl` |
| Export | `pdf` + `printing` (PDF), `excel` (real `.xlsx`) — see §22 |
| CSV | `csv` — parsing for the (currently hidden) CSV import feature, see §20 |
| Logging | `logger` wrapped by `LoggerService` |
| Local storage | `shared_preferences` (remember-me, last email, notification dedup keys) |
| Hosting | Firebase Hosting serving `build/web` with SPA rewrite to `/index.html` |

Declared but **still not imported anywhere in `lib/`**: `cached_network_image`, `shimmer`, `uuid`, `image_picker`, `path_provider`, `connectivity_plus`. Don't assume they are wired up; check before relying on them. (`firebase_storage`, `file_picker`, `flutter_svg` and `url_launcher` were on this list before but are now genuinely used — attachments, the attachment/CSV file pickers, the Google sign-in button icon, and opening attachment URLs/the About page's links, respectively.)

UI library: plain Material 3 — no third-party component kit, no custom fonts (`assets/fonts/` is empty).

## 3. Project Structure

```
lib/
  main.dart                 # runZonedGuarded → FirebaseService.initialize → ProviderScope(ErrorBoundary(EazyVaultApp))
  firebase_options.dart     # NOT committed — generate with `flutterfire configure`
  core/
    config/app_config.dart  # app name, page size (20), currency, durations
    constants/              # AppConstants (collection/field names), RouteConstants, ValidationConstants,
                            # AppSpacing, Breakpoints
    exceptions/             # AppException hierarchy (thrown by data sources)
    models/failure.dart     # freezed Failure union (returned by repositories)
    extensions/             # BuildContext (theme, breakpoints, snackbars, dialogs), DateTime, double, String
    router/app_router.dart  # GoRouter as a Riverpod provider
    services/               # FirebaseService (init), LoggerService
    theme/                  # AppColors, AppTheme (light + dark)
    utils/                  # Validators, CurrencyUtils, DateTimeUtils
    widgets/                # shared widgets: AppTextField, ConfirmationDialog, EmptyState, ErrorView,
                            # LoadingIndicator, SplashScreen, ErrorBoundary, navigation/ (AppScaffold,
                            # BottomNavBar, NavigationRailSidebar — live, wrapped around the main tabs
                            # by a ShellRoute, see §4)
    animations/             # page transitions
  features/<feature>/
    data/
      datasources/          # *_remote_datasource.dart — direct Firestore access (abstract + Impl)
      models/               # freezed models with fromFirestore/toFirestore
      repositories/         # *_repository_impl.dart
    domain/
      enums/                # AccountType, CategoryType, TransactionType (+ displayName/icon getters)
      repositories/         # abstract repository interfaces
      services/             # multi-document business logic (transactions only)
      models/, extensions/  # (transactions only) LoanMetadata/TransferMetadata, metadata accessors
    presentation/
      pages/                # routed full-screen pages
      widgets/              # feature widgets, including *_modal.dart dialogs and *_form.dart
      providers/            # *_providers.dart (DI wiring), *_notifier.dart (stateful notifiers)
test/
  helpers/                  # MockFirebase (fake_cloud_firestore, firebase_auth_mocks), TestHelpers
  unit/                     # 14 files — AccountBalanceService/TransactionsRepository plus budgets,
                            # recurring transactions, notifications, CSV import, net worth and reports
  widget/                   # transfer_transaction_form_test.dart
  widget_test.dart          # real Validators tests (not the stale counter template any more)
```

Features (13 directories under `lib/features/`): `authentication`, `accounts`, `categories`, `transactions`, `dashboard`, `budgets`, `recurring_transactions`, `reports`, `about`, `onboarding`, `user_manual`, `notifications`, `csv_import`. All are reachable from the UI except `csv_import` (see §20). There **is** a `settings`/`profile` feature: `features/authentication/presentation/pages/profile_page.dart` (`ProfilePage`), routed at both `/profile` and `/settings`. `dashboard` owns two bits of real domain logic beyond composing other features: `AccountFinancials` and a net-worth-over-time calculation (`domain/services/net_worth_service.dart` + `net_worth_calculator.dart`, reusing `AccountBalanceService.signedAmountFor` — see §22). `reports` composes `transactions`/`accounts`/`categories` the same way — no Firestore access of its own.

Where things go:
- New screen reachable by URL → `features/<f>/presentation/pages/` + route in `app_router.dart` + path in `RouteConstants`.
- Dialog/modal or form piece → `features/<f>/presentation/widgets/`.
- Widget used by 2+ features → `core/widgets/`.
- Firestore model → `features/<f>/data/models/`; enum → `domain/enums/`.
- Firestore reads/writes → data source; logic spanning several documents (balances, loans) → `domain/services/`.
- Providers → `presentation/providers/`.
- Constants/magic strings → `core/constants/`; helpers → `core/utils/` or `core/extensions/`.

## 4. Architecture

Feature-first, layered: **Widget → Notifier/provider → Repository → RemoteDataSource → Firestore** for reads. **All transaction writes go through `AccountBalanceService`** (`features/transactions/domain/services/`), which writes the transaction document *and* its balance changes in one Firestore `runTransaction`. The transactions data source is read-only.

### Data flow (example: create expense)
1. Widget (`AddTransactionDialog` / `AddEditTransactionPage`) validates with `Validators` (`positiveAmount` for money), builds a `TransactionModel` with `id: ''`, `createdBy: user.uid`, timestamps `DateTime.now()`.
2. Calls `ref.read(transactionsNotifierProvider.notifier).createTransaction(model)` → returns `Future<Failure?>` (`null` = success).
3. `TransactionsNotifier._mutate` keeps the auto-dispose notifier alive (`ref.keepAlive()`), calls `TransactionsRepository.createTransaction(uid, model)`.
4. `TransactionsRepositoryImpl` → `AccountBalanceService.createTransaction`: one Firestore transaction reads the affected accounts (and linked loan), writes the transaction doc, the new balances and any loan update. Exceptions → `(transaction: ..., failure: Failure?)`.
5. On success the notifier calls `refreshFinancialData(ref.invalidate)` (`transactions/presentation/providers/financial_refresh.dart`, which invalidates accounts, dashboard stats and loan providers) and reloads the list. On failure the list state is **not** replaced; the widget shows `failure.message`.

### Dependency wiring
- `auth_providers.dart` owns the root singletons: `firebaseAuthProvider`, `firebaseFirestoreProvider`, `googleSignInProvider`, `sharedPreferencesProvider`, `authStateChangesProvider`, `currentUserProvider`. Other features import these.
- Each feature's `*_providers.dart` builds `DataSourceImpl(firestore: ref.watch(firebaseFirestoreProvider))` → `RepositoryImpl(...)` with `@Riverpod(keepAlive: true)`.
- `accountBalanceServiceProvider` (in `transactions_providers.dart`) is injected into the repository, `transferServiceProvider` and `loanServiceProvider`. Everything takes Firestore from `firebaseFirestoreProvider`.
- Auth repository providers are async (`FutureProvider`) because they await `SharedPreferences`; use `await ref.read(authRepositoryProvider.future)`.

### Navigation architecture
- `appRouterProvider` (keepAlive) builds the `GoRouter` **once** and re-runs `redirect` via `refreshListenable` (a `ValueNotifier` fed by `authStateChangesProvider`). Redirect: auth loading → `/?from=<requested>` (splash); unauthenticated → `/login?from=<requested>`; authenticated on splash/auth route → `from` or `/dashboard`. `from` is validated by `_safeFrom` (in-app absolute paths only). The splash screen never navigates itself.
- **There is a `ShellRoute`** (`app_router.dart`, around line 99) wrapping `AppScaffold` around the four main tabs — Dashboard, Accounts, Categories, Transactions — each rendered as a `NoTransitionPage` so only the tab content swaps, not the whole screen; the persistent chrome around it is `BottomNavBar` (<600px), a collapsed `NavigationRailSidebar` (600–1024px), or an extended rail (≥1024px). Every other route (splash/login/register/forgot-password, add/edit/detail pages, `/reports`, `/about`, `/getting-started`, `/manual`, `/profile`, `/settings`, `/transactions/import`) sits outside the shell and builds its own `Scaffold`.
- **In practice the dashboard is still the hub:** most interactions (add income/expense, transfer, loans, accounts list, categories list, all transactions, transaction detail, budgets, recurring transactions) open as `showDialog` modals from `DashboardPage`, not as route navigations. Routed pages (`/accounts`, `/categories`, `/transactions`, add/edit/detail) exist too and are reachable via `context.push`. When adding UI, match whichever surface the similar feature already uses.
- `/transactions/import` currently routes to `ImportComingSoonPage`, a placeholder, rather than the real `CsvImportPage` — see §20.

### Multi-tenancy / roles
- Not multi-tenant, no roles or permissions. Isolation is **per Firebase Auth user**: every document lives under `users/{uid}/...`, and every repository/notifier method takes the uid from `currentUserProvider`.

## 5. Database / Firebase

Firebase project id: `eazy-vault-dev` (from `firebase.json`). No other environments are configured.

### Firestore layout
```
users/{uid}                        # UserModel: email, displayName, photoUrl, emailVerified, createdAt, updatedAt
users/{uid}/accounts/{id}          # name, type, openingBalance, currentBalance, color(int ARGB), icon(string),
                                   # isActive, description, createdAt, updatedAt, createdBy, isDeleted
users/{uid}/categories/{id}        # name, type, color, icon, description, isDefault, isActive, + audit fields
users/{uid}/transactions/{id}      # type, amount, accountId, categoryId, date(Timestamp), description, vendor,
                                   # attachments(List<String>, real Storage download URLs — see §10),
                                   # metadata(Map), incomePeriod(String?, income only — see §21
                                   # "Income Reporting Period vs Money Movement Date"), + audit fields
users/{uid}/budgets/{id}           # categoryId, amount (monthly limit), isActive, + audit fields — no
                                   # period field, always the current calendar month (see §21)
users/{uid}/recurringTransactions/{id}  # type, amount, accountId, categoryId, frequency, startDate,
                                   # endDate(nullable), description, vendor, + audit fields
```
(`profile` and `settings` sub-paths named in `AppConstants` are still unwritten by any code — editing your display name on `/profile`/`/settings` updates the `users/{uid}` doc itself, not a separate `profile` subcollection.)

Relationships are by id only (no references): `transaction.accountId → accounts`, `transaction.categoryId → categories`, loan repayment `metadata.linkedLoanId → transactions`, transfer `metadata.from/toAccountId → accounts`. Transfers and loans use **sentinel category ids** `'transfer'` and `'loan'` that don't exist in `categories` — code resolving category names must handle that.

### Query patterns
- Always `where('isDeleted', isEqualTo: false)` first, then equality filters, then `orderBy`.
- Transactions: optional `type`/`accountId`/`categoryId` + `date` range, `orderBy('date', desc)`, cursor pagination with `startAfterDocument`, default `limit(AppConfig.defaultPageSize)` = 20.
- Accounts: `orderBy('createdAt', desc)`; categories: optional `type`, `orderBy('createdAt', asc)`.
- Streams (`watchAccounts`, `watchTransactions`) back the dashboard's live lists.
- Aggregates (`getTotalByType`, `getTotalsByAccount`) fetch documents and sum client-side.

### Indexes (`firestore.indexes.json`)
Composite indexes all start with `isDeleted ASC`: transactions on `date` (asc/desc), `type+date` (asc/desc), `categoryId+date`, `accountId+date`; accounts on `createdAt desc`; categories on `createdAt`, `type+createdAt`, `type+sortOrder`. **Any new filter/order combination needs a new index** plus `firebase deploy --only firestore:indexes`. There is no index for combining two equality filters (e.g. `type` + `accountId`) with `date`.

### Security rules (`firestore.rules`)
- Owner-only read/write under `users/{uid}`; everything else denied.
- Create on accounts/categories/transactions requires `createdBy == request.auth.uid`.
- **`delete` is denied** on those collections → soft delete via `isDeleted: true` is mandatory.
- User doc create requires `createdAt`, `updatedAt`, `createdBy`; updates can't change `createdAt`/`createdBy`. `UserModel.toFirestore()` writes `createdBy: uid` to satisfy this. A failed profile-doc write is logged but doesn't fail sign-up/sign-in (the Auth account already exists); it's retried on the next sign-in. The deployed rules haven't been verified against this file.
- Rules do no type or amount validation; the app does that.
- `storage.rules`: owner-only paths `users/{uid}/**`, `transactions/{uid}/{txId}/{file}` (≤5 MB, image/pdf), `profiles/{uid}/{file}` (images). `AttachmentUploadService` (§10) now uses the `transactions/{uid}/{txId}/{file}` path for real uploads, mirroring these same limits client-side (`maxFileSizeBytes`, `isAllowedContentType`).
- `firestore.rules` already has matching owner-only / `createdBy`-checked / `delete: false` `match` blocks for `budgets` and `recurringTransactions` (lines ~73 and ~82), and `firestore.indexes.json` has `isDeleted+createdAt` indexes for both — these were added correctly when those features shipped, just not previously reflected in this file's Firestore layout above.

## 6. Authentication & Authorization

- **Methods:** email/password (sign up with display name, sign in, password reset, email verification) and Google. `AuthRemoteDataSourceImpl` branches on `kIsWeb` (this app ships web-only, so this is the path that actually runs): `_firebaseAuth.signInWithPopup(GoogleAuthProvider())` directly — a code comment notes `google_sign_in`'s `signIn()` is deprecated/broken on web after Google's GIS migration. The old `GoogleSignIn.signIn()` → `GoogleAuthProvider.credential` → `signInWithCredential` path still exists for non-web, but there's no `android`/`ios` build target to run it. On first Google login a `users/{uid}` doc is created. The `google-signin-client_id` `<meta>` tag in `web/index.html` is still present but no longer load-bearing for the popup flow — leave it in place, but don't assume removing/changing it affects sign-in.
- **Password policy** (`Validators.password`): 8–128 chars with at least one uppercase letter, one lowercase letter and one digit.
- **Session:** Firebase Auth's own persistence. `authStateChangesProvider` (stream) is the source of truth for routing; `currentUserProvider` gives the `User?` synchronously. `AuthNotifier` (freezed `AuthState`: initial/loading/authenticated(UserModel)/unauthenticated/error) drives the auth pages and loads the Firestore `UserModel`.
- **Remember me / last email:** stored in `SharedPreferences` via `AuthLocalDataSource` (keys in `AppConstants.sharedPrefs*`).
- **Route protection:** only the `GoRouter.redirect` described in §4. Pages assume a logged-in user; notifiers return an `authenticationError` failure if `currentUserProvider` is null.
- **Authorization:** entirely by Firestore rules scoping to `request.auth.uid`. No roles/claims.
- Firebase error codes are mapped to user-friendly messages in `AuthRemoteDataSourceImpl._getAuthErrorMessage`.

## 7. UI/UX Conventions

- **Theme:** `AppTheme.lightTheme` / `darkTheme` both exist (Material 3), but `main.dart` hardcodes `themeMode: ThemeMode.dark` — the app is **always dark**, not system/auto, and there's no in-app toggle (`AppTheme.lightTheme` is currently unreachable). Use `context.colorScheme`, `context.textTheme` (from `ContextExtensions`), and `AppColors` constants — don't hard-code hex values.
- **Colors (`AppColors`):** primary emerald `#10B981`, secondary indigo `#6366F1`, error `#EF4444`, warning `#F59E0B`, info `#3B82F6`. Semantic `AppColors.income` (green) / `AppColors.expense` (red). Palettes: `chartColors`, `accountColors`, `categoryColors`. Account/category `color` is stored as an `int` (ARGB) and `icon` as a string (emoji).
- **Typography:** Material text theme with explicit sizes/weights defined in `AppTheme` (display 57/45/36 w700, headline 32/28/24, title 22…); system font.
- **Shape:** cards radius 12 with 1px `AppColors.border` and elevation 0; buttons/inputs radius 8; dialogs radius 16.
- **Spacing:** `AppSpacing` scale xs 4 / sm 8 / md 16 / lg 24 / xl 32 / xxl 48, with `paddingMD`, `gapMD`, `borderRadiusLG`, etc. Use these instead of raw numbers in new code.
- **Responsive:** `Breakpoints` mobile <600, tablet 600–1024, desktop ≥1024 (also `compactHeight`, `contentMaxWidth`=1200, `formMaxWidth`=560, `listDialogMaxWidth`=900); `context.isMobile/isTablet/isDesktop` wrap them. Adoption is wider than it used to be: `AppScaffold` itself (§4's `ShellRoute`) branches 3-way on width to pick bottom-nav vs. collapsed vs. extended rail, on top of the forms/dialogs that constrain width via `Breakpoints`. New layouts should use these helpers rather than raw pixel checks.
- **Reusable components:** `AppTextField`, `ConfirmationDialog`, `EmptyState`, `ErrorView`, `LoadingIndicator`; feature cards (`AccountCard`, `CategoryCard`, `TransactionCard`, `SummaryCard`); `ColorPickerDialog`, `IconPickerDialog`.
- **Feedback:** `context.showSuccessSnackBar` / `showErrorSnackBar` / `showInfoSnackBar`; confirmations via `showDialog<bool>` with an `AlertDialog` or `ConfirmationDialog`.
- **Forms:** `Form` + `GlobalKey<FormState>` + `Validators.*`; submit buttons show a local `_isLoading` spinner in a `ConsumerStatefulWidget`.
- No data tables are used; lists are `ListView`s of cards.

## 8. Coding Conventions

- **Files:** `snake_case.dart`; suffixes signal role: `_page`, `_modal`, `_dialog`, `_form`, `_card`, `_notifier`, `_providers`, `_remote_datasource`, `_repository_impl`, `_model`, `_service`.
- **Classes:** `XModel`, `XRepository` (abstract) / `XRepositoryImpl`, `XRemoteDataSource` / `XRemoteDataSourceImpl`, `XNotifier`, `XState`, `XPage`. Private fields `_camelCase`; constants classes use a private const constructor (`const AppConfig._();`).
- **Widgets:** `ConsumerWidget` for read-only, `ConsumerStatefulWidget` for forms/dialogs with controllers; private sub-widgets as `_Name` classes in the same file.
- **Imports:** existing code uses **relative imports** everywhere even though `always_use_package_imports` is enabled (500 lint hits). Match the surrounding file; don't mass-convert.
- **Models:** `@freezed` with `fromJson` (generated) **and** hand-written `factory fromFirestore(DocumentSnapshot)` + `toFirestore()` extension. Firestore uses the hand-written pair: `Timestamp` ↔ `DateTime`, enums as `.name` strings with `firstWhere(..., orElse:)` fallback, `num → double` casts. When adding a field, update both and re-run `build_runner`. New documents are created with `id: ''`; the data source assigns the Firestore id.
- **Null safety:** strict analyzer (`strict-casts`, `strict-inference`, `strict-raw-types`). Cast Firestore map values explicitly (`data['x'] as String?`).
- **Async/errors:** data sources `try { … } catch (e, st) { LoggerService.error(...); throw ServerException('Failed to …: $e'); }` (rethrow `AppException`s); repositories `on XException catch (e) → Failure.x(e.message)`; account/category/transaction notifier mutations return `Future<Failure?>` (`null` = success). `AuthNotifier` still returns `bool` and exposes errors via its `error` state.
- **Comments:** sparse; brief doc comments on service methods. Don't add verbose commentary.

## 9. State Management

- Riverpod with code generation only — write `@riverpod` / `@Riverpod(keepAlive: true)` functions and classes, then run `build_runner`. Don't hand-write `Provider(...)`/`StateNotifierProvider`.
- **Singletons/DI** (`keepAlive: true`): Firebase instances, data sources, repositories, services.
- **List state:** a `@riverpod class XNotifier` whose state is a freezed union (`initial`/`loading`/`loaded`/`error`; transactions adds `loadingMore` + `hasMore` + `lastDocument` for pagination). `build()` kicks off `_loadX()` and returns `initial`. Mutations go through a private `_mutate` helper: `ref.keepAlive()` for the duration, call the repository, return the `Failure?`, and on success reload the list (and, for transactions, `refreshFinancialData`). A failed mutation leaves the loaded list in place. Consume with `state.when(...)` / `maybeWhen<List<T>>(…, orElse: () => <T>[])` (type the lists; untyped `[]` becomes `dynamic` and trips strict-casts).
- **Read-only derived data:** functional providers returning `Future`/`Stream`, e.g. `accountProvider(id)` (family), `accountsStreamProvider`, `totalBalanceProvider`, `currentMonthStatsProvider`, `accountFinancialsProvider`, `activeLoansProvider`. Consume `AsyncValue` with `.when(data:, loading:, error:)`.
- In `build` use `ref.watch`; in callbacks use `ref.read(xProvider.notifier)`. After any money-moving write that doesn't go through `TransactionsNotifier` (transfer/repayment forms call services directly), call `refreshFinancialData(ref.invalidate)`.
- `TransactionsNotifier` keeps `TransactionFilters` (type/account/category/date/searchQuery) as a private field. Filters are applied in Firestore; `searchQuery` is applied client-side to each loaded page (description, vendor, amount, type name). The `/transactions` page's search button opens a query dialog; its filter button opens `TransactionsModal`, which applies filters to the same notifier.
- Dashboard "recent transactions" is the `recentTransactionsProvider(limit:)` stream in `transactions_notifier.dart` (live, no invalidation needed).

## 10. API / Service Layer

- No HTTP APIs; "services" means Firestore-backed classes.
- **Data sources:** Firestore reads and account/category CRUD; build paths with `_firestore.collection(AppConstants.userCollection).doc(uid).collection(AppConstants.xCollection)`; soft delete = `update({isDeleted: true, updatedAt: now})`. The transactions data source has **no write methods** — never add a transaction write that bypasses `AccountBalanceService`. Accounts: `updateAccount` is a transactional partial update (never writes `currentBalance` from the client; applies an `openingBalance` change as a delta); `deleteAccount` refuses if any non-deleted transaction references the account (`accountId` or `metadata.toAccountId`); `getAccount` treats soft-deleted as not found. Categories data source also has `seedDefaultCategories` (runs only if the user has no categories).
- **Repositories:** wrap data sources/services, convert exceptions to `Failure` (including `NotFound`/`Validation`). Return records like `({List<AccountModel> accounts, Failure? failure})`; delete returns `Future<Failure?>`. `TransactionsRepository.updateTransaction(uid, tx)` takes no "old" copy — the service reads the stored version.
- **Domain services** (`features/transactions/domain/services/`): `AccountBalanceService` (`createTransaction` / `updateTransaction` / `deleteTransaction`, all atomic; `isEditableType`), `TransferService` (validates and creates the transfer via the balance service with a non-negative check on the source; `reverseTransfer`), `LoanService` (active/overdue loans, totals, `recordRepayment(userId, repayment)` → balance service), `AttachmentUploadService` (Storage upload/delete for transaction attachments, 5 MB + image/pdf check mirroring `storage.rules`), `TransactionExportService` (CSV/PDF/Excel for the Transaction Statement report, see §22). They throw `AppException`s; forms that call them directly catch `AppException` and show `e.message`.
- **Other domain services, not in `transactions/`** — add these if you're looking for "where does X get computed":
  - `RecurringTransactionService` (`features/recurring_transactions/domain/services/`) — client-side catch-up only (no server scheduler); on app open, creates any transactions a rule owes since it last ran (capped at 24/run) via the normal `TransactionsRepository.createTransaction` path, so it goes through `AccountBalanceService` like any manual entry.
  - `AlertEvaluator` (`features/notifications/domain/services/`) — pure, no Firestore/browser APIs: budget-threshold (80/90/100%, highest-only) and loan-due-date (3 days out / tomorrow / today / overdue-daily) alert logic, unit-tested directly.
  - `NotificationDispatchService` (`features/notifications/domain/services/`) — turns new `AlertEvaluator` output into a browser notification via `WebNotifier`, once per dedup key (local-prefs-backed); the in-app bell shows every current alert regardless of what's already been dispatched as a popup.
  - `CsvImportService` (`features/csv_import/domain/services/`) — parses/dedupes a CSV and imports rows through `TransactionsRepository` (never writes Firestore directly); built and unit-tested but not currently reachable from the UI, see §20.
  - `NetWorthService` / `NetWorthCalculator` (`features/dashboard/domain/services/`) — the dashboard's net-worth-over-time chart, reusing `AccountBalanceService.signedAmountFor` (§22) rather than re-deriving balance effects.
- `metadata` parsing: `transaction_extensions.dart` exposes typed accessors (e.g. `transferMetadata`) over the raw map using `LoanMetadata.fromJson`/`TransferMetadata.fromJson`.
- New Firestore functionality: add to the feature's data source interface + impl, expose via the repository interface + impl returning `Failure?`, then a provider/notifier method.

## 11. Feature Development Workflow

1. Find the closest existing feature (accounts is the cleanest full-stack example) and mirror its files.
2. Model: freezed model with `fromFirestore`/`toFirestore`, audit fields (`createdAt`, `updatedAt`, `createdBy`, `isDeleted`). Enum in `domain/enums` with `displayName`/`icon`.
3. Data source + repository (interface + impl) as above. New query shape → add index to `firestore.indexes.json`.
4. If a new collection: add a `match` block under `users/{userId}` in `firestore.rules` mirroring existing ones (owner-only, `createdBy` check on create, `delete: false`), and a name constant in `AppConstants`.
5. Providers file (`keepAlive` DI) + notifier with freezed state.
6. Run `dart run build_runner build --delete-conflicting-outputs`.
7. UI: page in `pages/` (and route + `RouteConstants`) and/or a modal in `widgets/` opened from the dashboard. Handle loading/error/empty via `LoadingIndicator`/`ErrorView`/`EmptyState`; validate with `Validators`.
8. If it moves money, go through the balance logic (§21) and invalidate `accountsNotifierProvider`.
9. `flutter analyze` on changed files; add/update tests under `test/unit` with `MockFirebase`.
10. Check in Chrome at mobile (<600), tablet and desktop widths, light and dark.

## 12. Web-Specific Guidelines

- Web is the only configured platform (no `android/`/`ios/` dirs). Run with `-d chrome`.
- URL strategy is the default **hash** strategy (`/#/dashboard`); `usePathUrlStrategy` is not called. Hosting still rewrites all paths to `index.html`.
- Deep links to routed pages (e.g. `/#/accounts/<id>`) work after refresh because pages load data by id from Firestore. State that exists only in dialogs is lost on refresh.
- On refresh the router shows splash (with `?from=`) until `authStateChanges` emits, then returns the user to the requested page. Don't add redirects that assume auth is known synchronously, and keep `from` handling when adding auth routes.
- Keep layouts usable at desktop widths (constrain dialog/form width; don't stretch forms full-width). `showModalBottomSheet` is used only once; prefer `showDialog` like the rest of the app.
- Keyboard/mouse: use standard Material widgets so tab focus and hover work; avoid gesture-only interactions.

## 13. Error Handling & Logging

- `main.dart` wraps the app in `runZonedGuarded` and sets `FlutterError.onError` / `PlatformDispatcher.onError` to log. `ErrorBoundary` widget then overrides `FlutterError.onError` again: it ignores RenderFlex overflow errors (logged as warnings) and otherwise replaces the whole app with its own error screen (separate `MaterialApp`) that has a reset button.
- Handlers **chain**: `main.dart` installs logging handlers first; `FirebaseService._initializeCrashlytics` (release, non-web only) wraps them; `ErrorBoundary` wraps that and forwards non-overflow errors to the previous handler. When adding a handler, capture the previous one and call it.
- **No crash reporting on web**: `firebase_crashlytics` has no web implementation, so it's skipped on web. Errors are only logged to the browser console. A web-capable reporter hasn't been chosen yet (PROJECT_AUDIT Q-8).
- `LoggerService.debug/info` print only in debug; `warning/error` always. Use it instead of `print` (`avoid_print` is on).
- Layers: data source throws `AppException` subclass → repository returns `Failure` → notifier stores `error(failure)` or returns `false` → UI shows `failure.message` in a snackbar or `ErrorView`.
- Validation: form-level via `Validators` (limits in `ValidationConstants`, e.g. amount ≤ 999,999,999.99, names 2–50 chars, password ≥ 8); service-level via `ValidationException` (transfer same account, insufficient balance, repayment over remaining amount).
- Firestore index errors show up as `FAILED_PRECONDITION` with a console link; fix by adding the index to `firestore.indexes.json`.

## 14. Security

- `lib/firebase_options.dart` is generated locally and not committed; don't commit it or paste its values into docs/code.
- All authorization is Firestore/Storage rules keyed to `request.auth.uid`. Any new collection must sit under `users/{uid}` with owner-only rules; never add a top-level collection readable by other users.
- Always derive the uid from `currentUserProvider` / `request.auth`, never from user input or route params.
- Keep `createdBy` set on creates (rules enforce it) and keep deletes soft (rules forbid hard deletes).
- Rules don't validate field types/amounts, so client validation (`Validators`, service checks) is the only guard today — don't remove it.
- Rules can't enforce balance consistency. A client can write any `currentBalance`, so balance correctness depends entirely on the service code.
- In `storage.rules`, `profiles/{uid}/*` is readable by **any** signed-in user, unlike every other path. Keep that in mind if profile images are ever implemented.
- `LoggerService.info` logs user ids and Firestore paths, but only in debug builds (`kDebugMode`). Don't move sensitive data into `warning`/`error` logs, which also run in release.

## 15. Performance

- Always paginate transaction lists (`limit` + `startAfterDocument`); the page size is `AppConfig.defaultPageSize`.
- Totals (`getTotalByType`, `getTotalsByAccount`, loan totals) read every matching document and sum on the client; avoid calling them in loops or per-widget. The spending-trends chart (`last6MonthsStatsProvider`) uses one range query (`getMonthlyTotals`) for the last 6 months.
- Prefer one stream/provider shared via Riverpod over each widget querying Firestore itself; watch the narrowest provider and use `select` where only part of the state is needed.
- Balances are denormalized in `currentBalance` precisely so the dashboard doesn't have to sum all transactions.
- `firebase.json` hosting headers: `no-cache` (revalidate) for `index.html` and all `js/css/json/wasm`, because Flutter web output is **not** content-hashed (`main.dart.js`, `flutter_bootstrap.js` keep fixed names); images `max-age=86400`; plus `X-Frame-Options: SAMEORIGIN`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` on everything. Don't reintroduce long `max-age` on unhashed files.
- Bundled assets are only the two root files declared in `pubspec.yaml`: `eazyvault_logo.png` (~1.2 MB, used on splash + auth screens) and `avail404.png` (splash). The `assets/` directory is **not** declared, so files placed there won't load until you add them to `pubspec.yaml`. `AssetConstants.empty*`/`errorIllustration` point to SVGs that don't exist. Don't reference them.

## 16. Testing

- 16 test files (the "54 tests, all passing" count is from the 2026-09-28 pass and wasn't re-verifiable this round — no Flutter SDK available; re-run `flutter test` and update this number before trusting it), all over `fake_cloud_firestore` with real classes:
  - `test/unit/account_balance_service_test.dart` — balance effect of every `TransactionType` on create/update/delete, transfers, repayments and loan status, stale-copy updates, installments serialization.
  - `test/unit/transactions_repository_test.dart` — repository reads/writes and `Failure` mapping.
  - `test/unit/accounts_remote_datasource_test.dart` — opening-balance delta, no stale `currentBalance` writes, delete guards.
  - `test/unit/transfer_and_loan_service_test.dart` — `TransferService`, `LoanService.recordRepayment`.
  - `test/unit/currency_utils_test.dart` — sign handling in currency formatting/parsing, `roundToDecimal`.
  - `test/widget/transfer_transaction_form_test.dart` — drives the real transfer form (UI → provider → service) and checks both balances; overrides `firebaseFirestoreProvider` and `currentUserProvider`.
  - `test/widget_test.dart` — real `Validators` tests (`positiveAmount`, `password`); **not** a leftover stub any more, despite the name.
  - `account_balance_service_test.dart` also covers `recalculateBalances` and repairing transfers that lost their destination.
  - `test/unit/income_period_test.dart` — `IncomePeriod` format/parse and the `effectiveIncomePeriod`/`incomeReportingMonth`/`hasDistinctIncomePeriod` fallback logic (pure Dart, no Firestore).
  - `test/unit/income_reporting_test.dart` — the income-reporting-period business rule end to end against `fake_cloud_firestore`: cross-month and same-month income, the year-boundary case, the legacy-record fallback, editing `incomePeriod` without touching the account balance, and deleting an income correctly affecting both.
  - `test/unit/alert_evaluator_test.dart` — budget-threshold and bill-due-date alert logic (pure, no Firestore).
  - `test/unit/categories_remote_datasource_test.dart` — categories CRUD, soft-delete, default seeding.
  - `test/unit/csv_import_service_test.dart` — CSV parsing/dedup/import, despite the UI entry point being hidden (see §20).
  - `test/unit/net_worth_calculator_test.dart` and `test/unit/net_worth_service_test.dart` — the dashboard net-worth-over-time calculation.
  - `test/unit/recurring_transactions_notifier_test.dart` — recurring transaction CRUD/notifier state.
  - `test/unit/report_calculation_service_test.dart` (the largest test file in the repo) — the reports feature's calculation layer, §22.
- `test/helpers/` provides `MockFirebase.getFakeFirestore()` (re-exports `FakeFirebaseFirestore`), `getMockAuth()`, `seedFirestore(firestore, uid)` and `TestHelpers.testUserId`. Seed: `account-1` (cash, 10000), `account-2` (savings, 50000), `category-1` (expense), `category-2` (income), `transaction-1` (expense 500 on `account-1`, treated as already reflected in the seeded balance). Import app code as `package:eazyvault/...`.
- No Firestore rules tests. No test file for budgets despite the feature being fully implemented — a real gap, not just a doc gap, worth closing.
- Commands: `flutter test`, `flutter test test/unit/account_balance_service_test.dart`, `flutter test --plain-name "should increase balance"`.
- Highest-value areas to test: balance effects of every `TransactionType` (create/update/delete), transfers, loan repayment status transitions, soft-delete filtering, repository `Failure` mapping.

## 17. Build / Run / Deployment

```bash
flutter pub get
dart pub global activate flutterfire_cli                     # if `flutterfire` isn't installed
flutterfire configure                                        # once: generates lib/firebase_options.dart (gitignored)
dart run build_runner build --delete-conflicting-outputs     # required on fresh checkout; *.g.dart / *.freezed.dart are gitignored
dart run build_runner watch --delete-conflicting-outputs     # during development
flutter run -d chrome
flutter analyze
flutter build web --release
firebase deploy --only hosting
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only storage
```
- Verified on 2026-09-28: with a `firebase_options.dart` present, `flutter build web --release` succeeds despite the analyzer errors listed in §20.
- Configuration: `AppConfig` constants only; there are no flavors, `.env` files, or `--dart-define` usage. The single Firebase project is `eazy-vault-dev`.
- Debug builds skip Analytics/Crashlytics init.
- No CI configuration exists in the repo.

## 18. Git Workflow

- Branches: `main` (default/PR target), `Develop`, feature branches like `feature/<name>`; remote also has `master`.
- Commit style seen: Conventional-Commit prefix (`feat: Add Transfer & Loans Management + Bug Fixes`).
- Generated files and `lib/generated/` are gitignored — never commit them.
- Keep changes focused; don't reformat or re-import unrelated files (the lint backlog makes diffs noisy fast).

## 19. AI Coding Agent Rules

- Inspect existing code before creating new code; find the most similar feature and follow its pattern (layers, naming, state union, snackbar feedback).
- Reuse `core/widgets`, `ContextExtensions`, `AppSpacing`, `AppColors`, `Validators`, `CurrencyUtils`, `AppConstants`/`RouteConstants` instead of re-creating them.
- Don't add packages when an existing dependency covers it. Don't assume an unused declared package (§2) is configured.
- Don't restructure folders or swap the architecture (Riverpod codegen, go_router, freezed, repository+`Failure`) without an explicit request.
- Don't modify unrelated files; don't "fix" the whole lint backlog as a side effect.
- Preserve existing behavior unless the task asks to change it — especially balance math, soft-delete, and rules.
- Before deleting/renaming, grep all usages (including generated `part` files and `ref.invalidate` calls).
- After changing models/providers, run `build_runner`; then run `flutter analyze` (compare against the pre-existing error baseline, §20) and relevant tests.
- Report assumptions, anything you couldn't verify (e.g. deployed rules vs `firestore.rules`), and balance-affecting changes explicitly.
- Treat the root `*_SUMMARY.md`/`*_STATUS.md` files as outdated; don't update them unless asked.
- Don't "fix" the known balance bugs (§20) as a side effect of another task. Stored balances in production already reflect the current behavior, so changing the math needs an explicit request and a plan for existing data.
- When touching any code that lists or loads transactions, remember `type` may be any of the six `TransactionType`s and `categoryId` may be `'transfer'`/`'loan'`. Don't assume income/expense only.
- Don't create `lib/firebase_options.dart` with real values in commits. It's gitignored. For local build checks a placeholder is fine; delete it afterwards.
- Security-rule changes need `firebase deploy --only firestore:rules` to take effect. Say so rather than implying a local edit is live.

## 20. Current Project Status

### Implemented
- Email/password + Google auth, forgot password, auth-guarded routing, splash.
- Accounts: CRUD (soft delete), detail page, color/icon pickers, total balance.
- Categories: CRUD, income/expense types, default category seeding (menu action / empty-state button).
- Transactions: income/expense CRUD with balance updates, paginated list, detail modal/page. Income carries an optional reporting period (`incomePeriod`, "Income For" in the UI) distinct from its credited date — see §21 "Income Reporting Period vs Money Movement Date".
- Transfers and loans (given/taken/repayment) via dashboard dialogs; `LoanService` status tracking.
- Dashboard: total balance, current-month income/expense, per-account financials chart, net-worth-over-time chart, recent transactions stream, quick actions, loans summary, upcoming bills (derived from active loans' due dates), category-wise expense breakdown chart. Theme is fixed dark (not dark "mode" as one of several — see §7).
- **Budgets** (`features/budgets/`): full CRUD — one monthly limit per expense category (categories already budgeted are excluded from the picker; a budget's category can't be changed after creation), opened via the dashboard's Budgets quick action (`BudgetsModal`/`AddEditBudgetModal`). "Spent" is computed at read time from the category's current-month expense total (`BudgetProgressProvider`), never stored — budgets don't touch `AccountBalanceService` (see §21).
- **Recurring transactions** (`features/recurring_transactions/`): full CRUD (Daily/Weekly/Monthly only, optional end date), opened via the dashboard's Recurring quick action. `RecurringTransactionService.catchUp` runs once per app session on open, generating any transactions a rule owes (capped at 24/run) through the normal `TransactionsRepository.createTransaction` path — so, unlike budgets, this **does** move money, correctly, with no bypass of `AccountBalanceService`.
- **Attachments**: real file upload (`AttachmentUploadService` → Firebase Storage, 5 MB limit, image/* or PDF), reachable from a transaction's detail view (`AttachmentsSection`) with upload-progress, view, and remove. Download URLs are stored in the transaction's `attachments` list.
- **Notifications**: an in-app bell (always shows current alerts) plus opt-in browser push (`NotificationDispatchService`/`WebNotifier`), both driven by `AlertEvaluator`'s pure budget-threshold (80/90/100%) and loan-due-date (3 days out / tomorrow / today / overdue-daily) logic. The toggle lives on `/profile`/`/settings`.
- **Profile & Settings** (`/profile` and `/settings`, both → `ProfilePage`): editable display name, read-only email/join date, the notification toggle, help links.
- **Onboarding**: a `WelcomeDialog` on first dashboard visit, and a `GettingStartedPage` walkthrough at `/getting-started`.
- **About** (`/about`) and **User Manual** (`/manual`, deep-linkable with `?section=`) informational pages, both linked from the dashboard's Quick Actions and from Profile & Settings.
- **Responsive navigation shell** (`AppScaffold`/`BottomNavBar`/`NavigationRailSidebar`) is live, wired via a `ShellRoute` around Dashboard/Accounts/Categories/Transactions (see §4) — it is not a stub.

### Partial / stubbed
- Loans: no dedicated page/route; `LoansSummaryCard` opens list dialogs (active / overdue) → `TransactionDetailModal`, which has a **Repayment** action (`LoanRepaymentForm`). Lend/Borrow buttons open `LoanTransactionForm`.
- **CSV import**: the real feature is fully built — `CsvImportPage`, `CsvImportService` (parse/dedupe/import through `TransactionsRepository`), `CsvColumnMapping`/`ParsedCsvRow`/`ImportOutcome` models, and its own unit test (`csv_import_service_test.dart`) — but deliberately unreachable: the `/transactions/import` route points at `ImportComingSoonPage` (a "Coming Soon" placeholder) instead, with a code comment noting how to swap the builder back. Treat this as "feature complete, entry point intentionally hidden," not "stubbed."
- No test coverage for budgets despite the feature being fully implemented (see §16) — a real gap, not a doc error.

The following were previously listed here as stubs/missing and are **no longer true** — confirmed implemented (see "Implemented" above for detail): category-wise expense breakdown, category delete UI, the responsive navigation shell, a Settings/Profile page, file-upload attachments. The previous claim that theme was "fixed to system mode" was also wrong — it's fixed to **dark**, not system (§7).

### Known technical debt / open items
- **Balances written by older app versions can be wrong** (transfers double-debited, borrowed money / repayments received subtracted, stale balances written back by account edits, transfers whose destination was erased by the old edit form). The user repairs them with the 🔄 **Sync balances** action (`recalculate_balances_action.dart`: dashboard Total Balance card, Accounts dialog, Accounts page) → `AccountBalanceService.recalculateBalances`, which rebuilds `currentBalance` = `openingBalance` + effects of all non-deleted transactions using the same rules as live writes. Transfers without `metadata.toAccountId` are listed (`brokenTransfers`) and repaired with `setTransferDestination`. It never runs automatically.
- Transfers, loans and repayments **can't be edited** (by design, `AccountBalanceService.isEditableType`); only deleted and re-created. A loan with repayments can't be deleted until its repayments are.
- Transfers require the source balance to stay ≥ 0, including `creditCard` accounts (PROJECT_AUDIT Q-3 undecided).
- Accounts are listed regardless of `isActive`; the flag only hides accounts from transaction forms.
- `getTotalsByAccount`, `getTotalByType`, `getMonthlyTotals` count only `income`/`expense` (PROJECT_AUDIT Q-4).
- `firestore.indexes.json` has a categories `type + sortOrder` index, but no model has a `sortOrder` field. New transactions indexes (type/account/category combinations + date) must be deployed with `firebase deploy --only firestore:indexes` before combined filters work.
- `flutter analyze` (after `build_runner`, with `firebase_options.dart` present): claimed **0 errors** as of 2026-09-28; **not re-verified** in this pass (no Flutter SDK available) despite several features' worth of new code since — re-run before trusting this number. Don't add new errors.
- No web crash reporting; Firestore rules have no field validation; no rules tests.
- A handful of declared dependencies are still unused (§2 — down to 6 after this pass's recheck). The README's mention of settings is no longer a doc/code mismatch (§3) — a real Settings/Profile page exists now.

### Don't change casually
- `firestore.rules` soft-delete/owner model, and the `users/{uid}/...` layout.
- `currentBalance` denormalization and anything in `AccountBalanceService`/`TransferService`/`LoanService` — changes alter users' stored balances. Data written before the balance fix may still be wrong (see above).
- `metadata` map shape for loans/transfers (stored data depends on `LoanMetadata`/`TransferMetadata` JSON keys).
- Enum `.name` strings (persisted in Firestore) — renaming an enum value breaks existing documents.
- Sentinel category ids `'transfer'` and `'loan'`.
- The `AccountBalanceService` / `date` vs. `incomePeriod` split (§21 "Income Reporting Period vs Money Movement Date") — `AccountBalanceService` must never read `incomePeriod`, and monthly income reporting must never switch back to `date`.

## 21. Important Implementation Notes

### Business rules as implemented
- **Balance effect per type** (`AccountBalanceService`): `income`, `loanTaken` → +amount; `expense`, `loanGiven` → −amount; `transfer` → −amount on `metadata.fromAccountId`, +amount on `metadata.toAccountId`; `loanRepayment` → +amount if the linked loan is `loanGiven` (money received), −amount if `loanTaken` (money paid). Update = revert stored version + apply new; delete = revert. Amount must be > 0.
- **Transfer** (`TransferService.createTransfer`): source ≠ destination; amount > 0; the source's balance must stay ≥ 0 (also for `creditCard`). The transfer record and both balances are written in one Firestore transaction. `reverseTransfer` creates a new opposite transfer; nothing in the UI calls it.
- **Loan created** (`LoanTransactionForm`): a `loanGiven`/`loanTaken` transaction with `categoryId: 'loan'`, `vendor` = party name, and `LoanMetadata` in `metadata` (status `pending`, optional installments generated in the form).
- **Loan repayment** (`LoanRepaymentForm`, opened from the loan's detail modal): a `loanRepayment` transaction with `metadata.linkedLoanId`. In the same Firestore transaction the balance service rejects amounts above `remainingAmount`, sets `remainingAmount -= amount` and status `completed` at 0, otherwise `partial`. Deleting a repayment restores the remaining amount (status back to `partial`/`pending`).
- `LoanMetadata` JSON: `build.yaml` has `explicit_to_json: true` so nested `installments` serialize as maps (required by Firestore).
- **Overdue** is computed, never stored: `TransactionModelExtensions.isOverdue` / `LoanService.getOverdueLoans` = not completed and `dueDate` in the past. Nothing writes `LoanStatus.overdue`; it only appears in UI switch statements.
- "Active" loans = not `completed`. The dashboard's upcoming bills come from active loans' due dates.
- Categories: seeding runs only when the user has no categories. The income/expense forms load categories filtered by the matching `CategoryType`.
- **What touches balances vs. what doesn't, among the newer features:** budgets (`BudgetProgressProvider`) and notifications (`AlertEvaluator`/`NotificationDispatchService`) are purely derived/read-only — they only read already-fetched data and never write Firestore balance-affecting fields; attachments only store a Storage URL on the transaction doc. Recurring transactions are the one newer feature that **does** move money, and it does so correctly: `RecurringTransactionService.catchUp` creates real transactions through `TransactionsRepository.createTransaction`, the same path a manual entry takes, so it still goes through `AccountBalanceService` — no bypass. Keep it that way if you touch recurring transactions.

### Income Reporting Period vs Money Movement Date

Two distinct dates can apply to an income transaction, and the codebase keeps them strictly separate:

- **Actual Money Movement Date** (`TransactionModel.date`, labeled "Credited Date" for income in the UI): when the money actually hit the account. This is the **only** date `AccountBalanceService` ever looks at — balances, `recalculateBalances`, and transfer/loan math are completely unaware of `incomePeriod`. Never change this to solve a reporting-month problem.
- **Income Reporting Period** (`TransactionModel.incomePeriod`, a `YYYY-MM` string, income only; labeled "Income For" in the UI): the calendar month this income counts toward on monthly dashboards and charts. Independent of `date` — e.g. money credited 30 Sep can be reported as October income. `null` means "use `date`'s month", which is also the automatic fallback for every income record written before this field existed (no migration needed). Use `TransactionModelExtensions.effectiveIncomePeriod` / `.incomeReportingMonth` rather than reading `incomePeriod` directly — they apply that fallback.

Rules this split depends on, enforced in `TransactionsRemoteDataSourceImpl`:
- Monthly income totals (`getTotalByType(..., TransactionType.income)`, the income side of `getTotalsByAccount` and `getMonthlyTotals`) query by `effectiveIncomePeriod`, not `date`. Expense totals, the transaction list, search, and every other filter are unaffected and still use `date`.
- The query is a merge of two indexed Firestore queries — `incomePeriod` range (explicit periods, wherever their credited date falls) and `date` range (the fallback for records with no `incomePeriod`) — deduped and re-filtered client-side by effective period. This avoids a full-collection scan while still covering legacy data with no migration. See `TransactionsRemoteDataSourceImpl._getIncomeTransactions`.
- `incomePeriod` has its own composite index (`isDeleted + type + incomePeriod`) in `firestore.indexes.json`.
- The Add/Edit Income forms (`add_edit_transaction_page.dart`, `add_transaction_dialog.dart`, `edit_transaction_modal.dart` — all three dashboard-modal and routed surfaces) default "Income For" to the credited date's month and keep following it if the credited date changes, *unless* the user has explicitly picked a different "Income For" month, in which case it stays fixed. A `showMonthYearPicker` (`core/widgets/month_year_picker.dart`) backs the "Income For" field — there's no built-in Flutter month picker.
- Never add a second place that re-derives monthly income/expense/net-savings/balance; the data source methods above are the only source of truth those dashboard providers and charts read from.

- Every money-moving change must answer: which account(s) change, by how much, in which direction, and on create **and** update **and** delete. That logic lives only in `AccountBalanceService._collectEffects`; change it there and extend `test/unit/account_balance_service_test.dart`.
- Firestore `runTransaction` requires all reads before writes — keep that order in services.
- Timestamps in documents are Firestore `Timestamp`; models hold `DateTime`. Month-range queries use local-time `DateTime(y, m, 1)` to `DateTime(y, m+1, 0, 23, 59, 59)`.
- After any write that changes balances outside `TransactionsNotifier`, call `refreshFinancialData(ref.invalidate)` or the dashboard shows stale numbers.
- Code generation must be re-run after editing any file with `part '*.g.dart'` / `part '*.freezed.dart'`.

## 22. Export & Reports

A `features/reports/` feature (now listed in §3's feature list) provides 8 report types, each exportable as PDF and `.xlsx`, reachable from the **Reports** quick action on the dashboard (route `/reports`, `ReportsPage`) and from contextual Export buttons on the Dashboard ("This Month"), Transactions page, and an account's detail page ("Export Statement").

### Architecture
```
Filters (ExportConfigSheet)
    → ReportCalculationService.<reportType>(...)   — the only place report numbers are computed
         → <ReportType>Data (domain/models/report_models.dart, plain Dart, no Firestore)
              → PdfReportService.build<ReportType>()   (pdf_report_kit.dart: shared header/footer/
                                                          summary tiles/table — one visual style for all 8)
              → ExcelReportService.build<ReportType>()  (real .xlsx via the `excel` package: numeric
                                                          amount cells, real dates, multi-sheet workbooks)
```
`ReportCalculationService` (`features/reports/domain/services/`) is built **only** from the app's existing repositories/services (`TransactionsRepository`, `AccountsRepository`, `CategoriesRepository`, `LoanService`) — it never queries Firestore directly, and PDF/Excel generation never recomputes a number independently, so a report's PDF and Excel always agree. `ReportType` (`domain/enums/report_type.dart`) is `monthly | transactionStatement | accountStatement | income | expense | category | loansDebts | annual`; its flags (`usesDateRange`, `usesSingleMonth`, `requiresAccount`, `supportsAccountFilter`, …) drive which filters `ExportConfigSheet` shows for a given type. `ExportConfigSheet` (`presentation/widgets/`) is the one reusable filter/live-preview/export dialog every entry point opens, parameterized by `ReportType`.

"Transaction Statement" is the one report type that doesn't use `PdfReportService`/`ExcelReportService`: it calls `TransactionExportService` (`features/transactions/domain/services/`, pre-existing) directly, which now has `buildCsv`/`buildPdf`/`buildExcel` — a flat transaction list needed no new rendering code.

### Date rules (same as §21 "Income Reporting Period vs Money Movement Date")
- **Account balances and account statements** (`AccountBalanceService.signedAmountFor`, a public static method mirroring the private per-account rules the live-write path already uses) always use a transaction's actual `date`, never `incomePeriod`. It now has a second consumer beyond reports: the dashboard's `NetWorthService`/`NetWorthCalculator` (§3/§10) reuses it too — keep both in mind under "Don't duplicate" below.
- **Monthly income** (the Monthly, Income, Category and Annual reports' income side) uses `incomePeriod` (`TransactionsRepository.getIncomeTransactions`, the public form of the hybrid incomePeriod/date query from §21).
- **Expense** reporting always uses `date` — there's no separate "expense period" concept.
- An account statement's running balance is computed from the account's `openingBalance` plus every non-deleted transaction affecting it up to the statement's end date (ascending), using `signedAmountFor`; the balance accumulated before the selected start date becomes the statement's displayed "Opening Balance" — this means the fetch is bounded by end date only, not the full range, so a very old account with a far-future "from" date still reads its entire prior history once.
- `TransactionsRepository.getAccountHistory` merges two queries — `accountId == X` and transfers where `metadata.toAccountId == X` — since a transfer's own `accountId` field is always its *source* account; a plain `accountId` filter alone would miss money transferred *into* the account.

### Report-by-report notes
- **Monthly**: one calendar month; Excel has Summary/Income/Expenses/Accounts sheets (Income/Expenses are transaction-level, not just category totals).
- **Account Statement**: single account, required; running balance; PDF resembles a bank statement (Date/Description/Debit/Credit/Balance).
- **Income / Expense**: date-range (income's range is read as a reporting-period range), optional account/category filters; both include a category breakdown.
- **Category**: expense categories grouped by `date`, income categories grouped by `incomePeriod`, over the same selected window — this is intentional, not a bug (see "Date rules" above).
- **Loans & Debts**: not date-filtered — "owed to you" / "you owe" as of now, same scope as the dashboard's `LoansSummaryCard`.
- **Annual**: a full year; `TransactionsRepository.getMonthlyTotals` (already incomePeriod-aware) drives the 12-row monthly breakdown.

### Firestore
New composite index `isDeleted + type + metadata.toAccountId + date` (for the transfer-in half of `getAccountHistory`) and `isDeleted + accountId + date ASC` (ascending, for statement ordering) in `firestore.indexes.json` — not yet deployed; needs `firebase deploy --only firestore:indexes`. No rules changes (rules don't validate fields, and reports only ever read the calling user's own `users/{uid}/...` data through the existing repositories).

### Don't duplicate
Never add a report-specific Firestore query or a report-specific balance/income calculation outside `ReportCalculationService` — every number a report shows should trace back to a `TransactionsRepository`/`AccountsRepository`/`CategoriesRepository`/`LoanService`/`AccountBalanceService` call already used elsewhere (dashboard, transaction list, account detail), so the dashboard and every report always agree. The dashboard's `NetWorthService` (§3/§10/§21) reusing `signedAmountFor` is the one other legitimate consumer of that balance math outside reports — don't add a third.
