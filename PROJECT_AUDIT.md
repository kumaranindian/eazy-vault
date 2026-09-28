# Project Production Audit — EazyVault

- **Audit date:** 2026-09-28
- **Branch / commit:** `feature/claude-verification` @ `18fa6b3`
- **Scope:** all of `lib/` (~18.3k hand-written lines), `test/`, `pubspec.yaml`, `build.yaml`, `analysis_options.yaml`, `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `web/`.
- **Method:** read the source and traced each user flow from the UI through the notifier, repository and service layers to Firestore. Ran `dart run build_runner build`, `flutter analyze`, `flutter test test/unit` and a release web build (using a temporary placeholder `lib/firebase_options.dart`, deleted afterwards). No application code was modified.
- **Evidence labels:** **Confirmed** means verified by reading the code path or by running a tool. **Highly likely** means derived from generated or framework code but not executed. **Potential** means a risk that depends on data, environment or intent.

---

## 1. Executive Summary

EazyVault is a single-user personal finance web app (Flutter web + Firebase Auth/Firestore). Users track accounts, income, expenses, transfers between accounts and personal loans, with a dashboard.

**Verdict: NOT production-ready.**

The architecture is reasonable and consistent: feature-first layering, Riverpod, a repository that returns `Failure`, and per-user Firestore isolation enforced by rules. The basic CRUD for accounts, categories and income/expense works. The blockers are all in **money correctness** and **core flows**:

1. **Balances go wrong.** Transfers debit the source account twice. "Loan taken" and repayments received *reduce* the balance. Editing a transfer or loan runs the income/expense math and erases its loan/transfer data.
2. **False success.** The transfer, loan and repayment forms show a success message even when saving failed.
3. **Broken flows.** Categories can't be edited or viewed: every category tap goes to an unregistered route. Loan repayment has no entry point in the UI. Loans with installments very likely fail to save.
4. **Auth vs. security rules.** The user profile document written at sign-up and first login doesn't include `createdBy`, which `firestore.rules` requires. With the repo's rules deployed, sign-up and first login show an error even though the Firebase Auth account exists and the user gets into the app.
5. **Stale data on the dashboard.** Adding, editing or deleting income/expense doesn't refresh account balances on the dashboard. Pull-to-refresh doesn't either.
6. **Operations and quality.** There's no working crash reporting. The test suite doesn't compile. The analyzer reports 47 errors. JS files are cached for a year without content-hashed names. There's no `.firebaserc` and no production Firebase project.

**Headline numbers:** 56 features reviewed. 11 COMPLETE · 24 PARTIALLY_COMPLETE · 11 BROKEN · 3 PLACEHOLDER · 6 MISSING · 1 UNKNOWN. 2 CRITICAL and 10 HIGH bugs, 13 P0 blockers.

---

## 2. Application Architecture

| Aspect | Finding |
|---|---|
| Users / roles | One role: an authenticated individual who owns their data. No admin, no sharing, no tenants. |
| Modules | `authentication`, `accounts`, `categories`, `transactions` (income, expense, transfer, loans), `dashboard` |
| Layers | Widget → Riverpod notifier/provider → Repository (returns records with `Failure?`) → RemoteDataSource (Firestore). Multi-document logic lives in `features/transactions/domain/services/` (`AccountBalanceService`, `TransferService`, `LoanService`). |
| State | `riverpod_generator` providers. Freezed union states (`initial/loading/loaded/error`). Most feature notifiers are auto-dispose. |
| Routing | `go_router`. A flat route list inside a Riverpod provider that rebuilds the whole `GoRouter` whenever auth changes (`lib/core/router/app_router.dart:25-31`). In practice the dashboard is the hub and opens most features as `showDialog` modals. |
| Data | `users/{uid}/{accounts,categories,transactions}/{id}` with soft delete (`isDeleted`). `currentBalance` is stored on each account and adjusted by the services. |
| Hosting | Firebase Hosting, SPA rewrite, hash URL strategy. Firebase project `eazy-vault-dev` only. |

Intended end-to-end workflow, pieced together from the UI:
Register/Login → Dashboard → seed/create categories → create accounts → record income/expense, transfers and loans from the dashboard quick actions → review recent transactions, the monthly summary, loans and upcoming due dates → browse or filter transactions in the "All transactions" modal or on the `/transactions` page.

---

## 3. Feature Coverage (inventory)

Columns: **UI** = UI exists · **Nav** = navigation exists · **Logic** = business logic · **DB** = database integration · **Val** = validation · **Err** = error handling · **Auth** = authorization · **L/E/S** = loading / empty / success states · **Resp** = responsive · **Safe** = production-safe.

### 3.1 Authentication
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| A1 | Email sign-up | PARTIALLY_COMPLETE | `register_page.dart:41-66` → `auth_remote_datasource.dart:90-123` | User doc create breaks the rules (BUG-05). The page shows an error but the Auth user is created and signed in. | P0 |
| A2 | Email sign-in | PARTIALLY_COMPLETE | `login_page.dart:55-80`, `auth_remote_datasource.dart:57-88` | If the user doc is missing, it tries to create it on every login and fails (BUG-05). Session UX issues (BUG-12). | P0 |
| A3 | Google sign-in | UNKNOWN | `auth_remote_datasource.dart:125-162`; client-id meta in `web/index.html:25` | Uses the legacy `google_sign_in` 6 `signIn()` flow on web. Can't be verified without real config. Also hits BUG-05 on first login. | P1 |
| A4 | Forgot password | COMPLETE | `forgot_password_page.dart`, `auth_remote_datasource.dart:182-197` | — | — |
| A5 | Email verification | PARTIALLY_COMPLETE | Sent at sign-up (`auth_remote_datasource.dart:112`). `sendEmailVerification`/`reloadUser` exist in the notifier but no UI calls them. | Not enforced, and there's no way to resend it. | P2 |
| A6 | Remember me | PARTIALLY_COMPLETE | `auth_repository_impl.dart:40-45`, `login_page.dart:36-43` | Only pre-fills the email. It has no effect on session persistence, although the checkbox implies it does. | P3 |
| A7 | Sign out | COMPLETE | `dashboard_page.dart:~100-125`, `auth_remote_datasource.dart:165-180` | — | — |
| A8 | Route guard / session restore | PARTIALLY_COMPLETE | `app_router.dart:27-55`, `splash_screen.dart:49-58` | Guard works. Deep links are lost on refresh, and there's a forced 3-second splash (BUG-12). | P1 |
| A9 | Profile page | MISSING | Only `RouteConstants.profile` exists; there's no route or page. | Potential requirement — confirmation needed | P3 |
| A10 | Settings page | MISSING | `RouteConstants.settings` and prefs key `theme_mode` exist, unused. The README lists a `settings/` feature. | Potential requirement — confirmation needed | P3 |

### 3.2 Accounts
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| AC1 | Create account | COMPLETE | `add_edit_account_page.dart`, `add_account_modal.dart` (two duplicate UIs), `accounts_remote_datasource.dart:~62-80` | Opening balance can't be negative (`Validators.amount`), which matters for credit cards (Q-3). | P2 |
| AC2 | List accounts | COMPLETE | `accounts_page.dart`, `accounts_modal.dart` (L/E/S states and `ErrorView` present) | — | — |
| AC3 | Account detail | PARTIALLY_COMPLETE | `account_detail_page.dart` | No transaction history for the account. Loads soft-deleted accounts (`getAccount` has no `isDeleted` check). | P2 |
| AC4 | Edit account | PARTIALLY_COMPLETE | `add_edit_account_page.dart:90-112`, `accounts_remote_datasource.dart:98` | Editing the opening balance doesn't change `currentBalance`. The whole document is overwritten with a stale balance (BUG-08). | P0 |
| AC5 | Delete account | PARTIALLY_COMPLETE | `account_detail_page.dart:61-86` (only entry point) | Soft delete leaves its transactions orphaned; there's no check for existing transactions (BUG-17). | P1 |
| AC6 | Active/inactive flag | PARTIALLY_COMPLETE | Hidden from transaction forms (`add_transaction_dialog.dart:146`) | Still listed, and still counted in the total balance. | P3 |
| AC7 | Total balance | PARTIALLY_COMPLETE | `accounts_notifier.dart:~150-162` | Stale after transactions (BUG-09). Includes inactive accounts. | P0 |

### 3.3 Categories
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| C1 | Seed default categories | COMPLETE | `categories_remote_datasource.dart:138-175` (skips if any exist) | — | — |
| C2 | Create category | COMPLETE | `add_edit_category_page.dart`, `add_category_modal.dart` (duplicates) | — | — |
| C3 | List by type (tabs) | COMPLETE | `categories_page.dart:82-121`, `categories_modal.dart` | — | — |
| C4 | Category detail | BROKEN | `categories_page.dart:160`, `categories_modal.dart:270` push `RouteConstants.categoryDetail` (`/categories/:id`), which isn't registered in `app_router.dart` | Tapping any category opens the router's "Page not found" screen (BUG-06). | P0 |
| C5 | Edit category | BROKEN | Route `/categories/:id/edit` exists, but **no UI navigates to it** (`RouteConstants.editCategory` is only used in the router) | Can't be reached (BUG-06). | P0 |
| C6 | Delete category | MISSING (UI) | Notifier/repository/data source support it (`categories_notifier.dart:~95-112`); no UI calls it | — | P2 |

### 3.4 Transactions, transfers and loans
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| T1 | Add income/expense (dashboard dialog) | PARTIALLY_COMPLETE | `add_transaction_dialog.dart:80-135` → `transactions_repository_impl.dart:84-89` | Works and the balance is updated in Firestore. Dashboard balances stay stale (BUG-09). Not atomic (BUG-10). | P0 |
| T2 | Add income/expense (`/transactions/add-*` page) | PARTIALLY_COMPLETE | `add_edit_transaction_page.dart:120-170` | Allows amount 0 (`Validators.amount` + `double.parse`). Same staleness and atomicity issues as T1. | P1 |
| T3 | Transaction list + pagination | PARTIALLY_COMPLETE | `transactions_page.dart:24-45` (scroll → `loadMore`), `transactions_notifier.dart:55-127` | Pagination works. Search and filter buttons are `// TODO` (`:91`, `:99`). | P2 |
| T4 | Filters (All-transactions modal) | PARTIALLY_COMPLETE | `transactions_modal.dart:95-160` → `applyFilters` | Combinations of filters need indexes that don't exist (BUG-13). The custom end date is exclusive (BUG-14). Filters leak into the shared notifier (BUG-16). | P1 |
| T5 | Search | PLACEHOLDER | `searchTransactions` stores `searchQuery`, which is never sent to the repository (`transactions_notifier.dart:79-87`) | Does nothing (BUG-15). | P2 |
| T6 | Transaction detail (page + modal) | PARTIALLY_COMPLETE | `transaction_detail_page.dart`, `transaction_detail_modal.dart` | Category shows "Unknown" for transfers/loans (placeholder category ids `'transfer'`/`'loan'`). | P3 |
| T7 | Edit income/expense | PARTIALLY_COMPLETE | `edit_transaction_modal.dart:110-165`, `add_edit_transaction_page.dart`; balance logic `account_balance_service.dart:55-104` | Balance maths correct for income/expense (including an account change). Dashboard balance stale (BUG-09). Not atomic (BUG-10). | P1 |
| T8 | Edit transfer/loan | BROKEN | Same forms, reachable from `transaction_detail_modal.dart:233` and `transactions_modal.dart:202` | Erases `metadata`, applies income/expense maths, and the type selector only offers income/expense (BUG-03). | P0 |
| T9 | Delete income/expense | PARTIALLY_COMPLETE | 5 entry points (dashboard, modal, page, detail page, detail modal) → `transactions_repository_impl.dart:138-147` | Soft delete then balance revert, not atomic (BUG-10). Dashboard balance stale (BUG-09). | P1 |
| T10 | Delete transfer/loan | BROKEN | Same entry points; `_revertBalance` (`account_balance_service.dart:122-147`) only touches `accountId` | Transfer: the destination account is never reverted. Loan: linked repayments and `remainingAmount` are untouched (BUG-01/02). | P0 |
| T11 | Attachments | PLACEHOLDER | Free-text `_attachmentController` stored as `attachments: [text]` (`edit_transaction_modal.dart:139-141`). No upload; `firebase_storage` is unused. | — | P3 |
| T12 | Transfer between accounts | BROKEN | `transfer_transaction_form.dart:74-118` → `transfer_service.dart:17-92` and then `createTransaction` | Source is debited twice (BUG-01). Success shown even on failure (BUG-04). | P0 |
| T13 | Loan given | PARTIALLY_COMPLETE | `loan_transaction_form.dart:95-160` | Balance direction is correct. Installments very likely fail (BUG-07). Success shown even on failure (BUG-04). | P0 |
| T14 | Loan taken | BROKEN | Same form; `account_balance_service.dart:36-38` subtracts for every non-income type | Borrowed money *reduces* the balance (BUG-02). | P0 |
| T15 | Loan installments | BROKEN (highly likely) | `loan_metadata.g.dart:38` writes `instance.installments` as objects; `build.yaml:19` `explicit_to_json: false` | Firestore can't serialize the nested objects, so saving fails (BUG-07). | P0 |
| T16 | Loan repayment | BROKEN (unreachable) | `LoanRepaymentForm` is never instantiated anywhere in `lib/` | No way to repay. If wired up, it would move the balance the wrong way for repayments received and also report false success (BUG-02/04). | P0 |
| T17 | Loans list page | MISSING | `loans_summary_card.dart:42` `// TODO: Navigate to loans page`; no route | Evidence: TODO in the code | P2 |
| T18 | Overdue detection | COMPLETE | `transaction_extensions.dart:60-66`, `loan_service.dart:67-85` (computed, never stored) | — | — |

### 3.5 Dashboard
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| D1 | Summary cards (total balance, month income/expense) | PARTIALLY_COMPLETE | `dashboard_page.dart:41-45, 180-210`; `dashboard_providers.dart:24-57` | Total balance stale (BUG-09). Monthly stats count only income/expense. | P0 |
| D2 | Recent transactions (live stream) | COMPLETE | `recentTransactionsProvider` (`transactions_notifier.dart:284`), `dashboard_page.dart:354-420` | — | — |
| D3 | Quick actions | COMPLETE | `dashboard_page.dart:241-315` open the dialogs | The actions they open have the bugs listed above. | — |
| D4 | Account breakdown chart / financial summary (header) | PARTIALLY_COMPLETE | `dashboard_header.dart`, `account_breakdown_chart.dart`, `dashboard_providers.dart:66-108` | Totals ignore transfers and loans (`transactions_remote_datasource.dart` `getTotalsByAccount`). | P2 |
| D5 | Loans summary card | PARTIALLY_COMPLETE | `loans_summary_card.dart` (totals via `LoanService`) | 4 buttons are empty `// TODO` handlers (`:42, :77, :149, :162`). | P1 |
| D6 | Upcoming bills | PARTIALLY_COMPLETE | `upcoming_bills_widget.dart:82-110` (from active loans' `dueDate`) | Ignores installment due dates; there are no bills other than loans. | P3 |
| D7 | Spending trends (6 months) | PLACEHOLDER | `spending_trends_provider.dart:26-45` splits the current month's totals evenly across 6 months | Shows made-up data as if real (BUG-25). | P1 |
| D8 | Category expense breakdown | MISSING | `dashboard_providers.dart:59` `// TODO` | Evidence: TODO in the code | P3 |

### 3.6 Platform / cross-cutting
| ID | Feature | Status | Evidence | Issues | Priority |
|---|---|---|---|---|---|
| P1 | Responsive navigation shell | BROKEN (dead code) | `core/widgets/navigation/*` isn't used anywhere. `navigation_rail_sidebar.dart:151` refers to an undefined `authNotifierProvider`. | Pages use their own `Scaffold`; there's no persistent navigation. | P2 |
| P2 | Theme / dark mode | COMPLETE | `app_theme.dart`, `ThemeMode.system` (`main.dart`) | No user toggle. | — |
| P3 | Error boundary | PARTIALLY_COMPLETE | `error_boundary.dart:28-60` | Swallows overflow errors and replaces the whole app with an error screen. Overwrites other error handlers (BUG-11). | P1 |
| P4 | Crash reporting | BROKEN | `firebase_service.dart:36-45` handlers are overwritten by `main.dart:23,31` and `error_boundary.dart:28`; Crashlytics has no web support | No production error visibility (BUG-11). | P0 |
| P5 | Analytics | PARTIALLY_COMPLETE | Collection enabled in release (`firebase_service.dart:52-60`) | No events are logged anywhere. | P3 |
| P6 | Deep link / refresh | BROKEN | `app_router.dart:25-31` rebuilds `GoRouter` at `initialLocation: '/'`; the splash then always goes to `/dashboard` | Refreshing any page lands on the dashboard after 3 seconds (BUG-12). | P1 |
| P7 | Offline / poor network handling | MISSING | `connectivity_plus` is declared but never imported | Potential requirement — confirmation needed | P2 |

**Responsive behaviour:** only 2 feature files branch on `Breakpoints`, and only 4 constrain width. Pages are mostly single-column. Dialogs are width-constrained. **Accessibility:** no `Semantics` or tooltips beyond Material defaults. Not formally audited.

---

## 4. Partially Implemented Features (summary)

A1, A2, A5, A6, A8 · AC3–AC7 · T1–T4, T6, T7, T9, T13 · D1, D4, D5, D6 · P3, P5 (24 total; details in §3).

The most common reasons they're only partial:
- Dashboard balances aren't refreshed after writes.
- A balance write and the transaction write aren't atomic.
- Buttons with `// TODO` handlers.
- Missing composite indexes.
- A field exists in the model but isn't used (`isActive`, `attachments`, `emailVerified`).

## 5. Missing Features

| ID | Feature | Evidence it's expected | Status |
|---|---|---|---|
| A9 | Profile page | `RouteConstants.profile`; Storage rule `profiles/{uid}` | Potential requirement — confirmation needed |
| A10 | Settings (theme toggle etc.) | `RouteConstants.settings`, prefs key `theme_mode`, README `settings/` | Potential requirement — confirmation needed |
| C6 | Delete category (UI) | Backend implemented, no UI | Missing UI |
| T17 | Loans list page | TODO `loans_summary_card.dart:42` | Required by existing TODO |
| T16 | Loan repayment entry point | Form exists, never opened | Required by existing loan workflow |
| D8 | Category breakdown | TODO `dashboard_providers.dart:59` | Required by existing TODO |
| P7 | Offline handling | `connectivity_plus` dependency | Potential requirement — confirmation needed |
| — | File attachments upload | `attachments` field, `storage.rules` transaction path, `file_picker`/`image_picker` deps | Potential requirement — confirmation needed |
| — | Account transaction history on the detail page | Account detail page exists; transactions are filterable by `accountId` | Potential requirement — confirmation needed |
| — | User account deletion / data export | Not referenced anywhere | Potential requirement — confirmation needed (compliance) |

---

## 6. Confirmed Bugs

| ID | Severity | Location | Problem | Root cause | Impact | Reproduction | Recommended fix |
|---|---|---|---|---|---|---|---|
| **BUG-01** | CRITICAL | `transfer_transaction_form.dart:74-110`; `transfer_service.dart:47-84`; `transactions_repository_impl.dart:89`; `account_balance_service.dart:36-38` | A transfer debits the source account twice. Deleting a transfer only credits the source back and never reverts the destination. | The form calls `createTransfer` (source −a, destination +a) and then `createTransaction(type: transfer)`, which runs `updateBalanceForNewTransaction` (source −a again). The revert only looks at `accountId`. | Wrong stored balances. The "insufficient balance" check is bypassed, so balances can go negative. | Cash 1000, Bank 0. Transfer 100 Cash→Bank. Result: Cash 800, Bank 100. | Make transfers one atomic operation: write the transaction document inside `TransferService`'s Firestore transaction and skip `AccountBalanceService` for `transfer`. Handle update/delete for both accounts. |
| **BUG-02** | CRITICAL | `account_balance_service.dart:36-38, 84-88, 138-140` | Every non-`income` type subtracts from the balance. So `loanTaken` (money received) lowers the balance, and a `loanRepayment` received on a `loanGiven` loan also lowers it. | The balance direction is decided by `isIncome` only. | Wrong balances for every loan taken and every repayment received. | Take a 500 loan into Cash (1000) → Cash 500 (expected 1500). | Add a per-type sign function, e.g. `TransactionType.balanceEffect`, that also takes the linked loan's direction into account. Use it for create, update and revert. Add tests. |
| **BUG-03** | HIGH | `edit_transaction_modal.dart:126-146`; `add_edit_transaction_page.dart:128-147`; `transactions_remote_datasource.dart:~186-188` | Editing any transaction rebuilds it **without `metadata`** and writes the full document, so loan and transfer data is erased. The type selector only offers income/expense. | A new `TransactionModel(...)` is built instead of calling `existing.copyWith(...)`, and `update(toFirestore())` sends `metadata: null`. | Loans lose their party, due date, status and `remainingAmount`. Transfers lose their destination account. Balances are recalculated with income/expense rules. | Open a transfer → Edit → Save. The Firestore doc now has `metadata: null`. | Block generic editing of transfer/loan types, or build dedicated edit flows. Always `copyWith` from the existing model. |
| **BUG-04** | HIGH | `transfer_transaction_form.dart:110-118`; `loan_transaction_form.dart:144-155`; `loan_repayment_form.dart:124-136` | The success snackbar is shown even if `createTransaction` failed. | The `Future<bool>` return value is ignored; failures only change notifier state, which isn't thrown. | The user believes money was recorded when it wasn't (or was only half-recorded, see BUG-01/07). | Force a Firestore failure (offline, or a loan with installments) → "completed successfully" still appears. | Check the returned `bool` and show the failure message, as `add_transaction_dialog.dart` does. |
| **BUG-05** | HIGH (if the repo's rules are deployed) | `auth_remote_datasource.dart:258-284`; `user_model.dart:36-47`; `firestore.rules:25-27` | The user document is written without `createdBy`, but the rule requires `hasAll(['createdAt','updatedAt','createdBy'])`. | Model and rules don't match. | Sign-up shows "Failed to sign up…" after the Auth user is already created and signed in. Every login tries to create the doc again and shows an error. `AuthNotifier` stays in `error`. The router still lets the user in (it uses `authStateChanges`). | Register a new email against the repo's rules. | Add `createdBy: uid` in `toFirestore()`, or relax the rule. Make sign-up tolerate a failed profile write. Confirm what the deployed rules actually are (Q-1). |
| **BUG-06** | HIGH | `categories_page.dart:160`; `categories_modal.dart:268-272`; `app_router.dart` (no `/categories/:id` route) | Tapping a category opens "Page not found". The edit page is unreachable. | The route constant `categoryDetail` isn't registered, and nothing links to `editCategory`. | Categories can't be edited or viewed after creation. | Categories → tap any category. | Point taps at `RouteConstants.editCategory`, or register a detail route. |
| **BUG-08** | HIGH | `add_edit_account_page.dart:90-112`; `accounts_remote_datasource.dart:~94-98` | Editing an account (1) ignores changes to the opening balance and (2) writes back the `currentBalance` loaded when the form opened. | Full-document `update(toFirestore())` with a stale snapshot; there's no delta logic for the opening balance. | (1) Fixing a wrong opening balance has no effect on the balance. (2) A lost update: any transaction saved while the edit form is open is silently reversed. | Open Edit Account. In another tab add income 100. Save the edit → the +100 is lost. | Update only the edited fields. Apply the opening-balance delta inside a Firestore transaction. Never write `currentBalance` from the form. |
| **BUG-09** | HIGH | `add_transaction_dialog.dart:126-128`; `edit_transaction_modal.dart:156-158`; `add_edit_transaction_page.dart:164-166`; `dashboard_page.dart:136-140, 543-546`; `transactions_modal.dart:191-193` | After an income/expense is added, edited or deleted, the dashboard's total balance and per-account balances don't change. Pull-to-refresh doesn't fix it. | `totalBalanceProvider` is computed from `accountsNotifierProvider`, which loads once with `get()`. These flows invalidate `totalBalanceProvider`, not `accountsNotifierProvider`. | The dashboard shows wrong balances until a full reload or the Accounts page's refresh. | Dashboard → Add Expense 100 → the total balance doesn't change. | Invalidate or refresh `accountsNotifierProvider` after every balance-affecting write, or make accounts a stream (`watchAccounts` already exists). |
| **BUG-10** | HIGH | `transactions_repository_impl.dart:84-89, 111-122, 143-146` | The transaction write and the balance update are two separate operations. | No batch or transaction spans both. | A failure between them leaves the stored balance out of sync with the transactions. On create, the user retries and ends up with a duplicate transaction. | Lose the network between the two calls (for example by throttling). | Do both inside one `runTransaction` (the data source can accept a `Transaction`), or use a Cloud Function. |
| **BUG-11** | HIGH | `main.dart:19-34`; `firebase_service.dart:34-49`; `error_boundary.dart:28-60` | Crashlytics handlers are overwritten twice, and `firebase_crashlytics` doesn't support web. | Handlers are assigned in sequence; the last assignment wins (`ErrorBoundary`). | There's no production error monitoring at all. | Throw in release → nothing reaches Firebase. | Choose a web-capable reporter (e.g. Sentry, or Cloud Logging through a function) and chain the handlers instead of replacing them. |
| **BUG-12** | MEDIUM | `app_router.dart:25-31`; `splash_screen.dart:49-58` | The whole `GoRouter` is rebuilt on every auth event with `initialLocation: '/'`. The splash always waits 3 seconds and then goes to `/dashboard`. | The router is created inside a provider that watches the auth stream, instead of using `refreshListenable`. | Refreshing or deep-linking always ends on the dashboard. Every login shows a 3-second splash. The navigation stack is reset. | Open `/#/accounts/<id>` and refresh → dashboard. | Create the `GoRouter` once. Use `refreshListenable` driven by auth. Honour `state.uri` after auth resolves. Drop the fixed delay. |
| **BUG-13** | MEDIUM | `transactions_remote_datasource.dart:84-106`; `firestore.indexes.json`; `transactions_modal.dart:118-124` | Filtering by two or more of type/account/category (with the date order) needs composite indexes that don't exist. | Only single-equality + `date` indexes are defined. | The All-transactions modal errors with `FAILED_PRECONDITION` for combined filters. | In the modal, choose Type = Expense and an Account. | Add the needed indexes, or filter secondary fields on the client. |
| **BUG-14** | MEDIUM | `transactions_modal.dart:143-157` | A custom date range's end date is midnight at the *start* of that day. | `picked.end` is used as-is with `isLessThanOrEqualTo`. | Transactions on the last day (any time after 00:00) are left out. Transactions added via the dashboard get `DateTime.now()`, so they have a time of day. | Custom range ending today → today's dashboard-added transactions are missing. | Use end-of-day (`DateTime(y,m,d,23,59,59,999)`) or `< nextDay`. |
| **BUG-15** | LOW | `transactions_notifier.dart:79-87, 226-229`; `transactions_page.dart:91,99` | Search and filter buttons do nothing; `searchQuery` is never applied. | Not implemented. | Visible but non-working UI. | Tap search on `/transactions`. | Implement client-side search, or hide the buttons. |
| **BUG-16** | MEDIUM | `transactions_notifier.dart:44-52, 150-200`; `accounts_notifier.dart:50-110` | (a) The modal's filters are kept in the shared notifier, so other screens show filtered data. (b) Any failed mutation replaces the whole loaded list with the `error` state. | Shared notifier state; error modelled as a full-screen state. | Confusing data, and lists vanish after a single failed delete. | Filter in the modal, close it, open `/transactions` while it's still alive → filtered list. | Scope filters per screen (family/parameters). Report mutation errors separately from list state. |
| **BUG-17** | MEDIUM | `accounts_remote_datasource.dart:~55-66, 109-122`; `account_detail_page.dart:61-86` | Deleting an account leaves its transactions in place and it keeps counting toward stats. `getAccount` returns soft-deleted accounts. | No reference checks; no `isDeleted` filter on get-by-id. | Orphaned transactions show "Unknown" account. Monthly income/expense totals still include deleted accounts' transactions. | Delete an account that has transactions → the dashboard monthly stats don't change. | Block the delete, archive instead, or cascade. Filter `isDeleted` in `getAccount`. |
| **BUG-21** | HIGH (process) | `test/helpers/mock_firebase.dart:6,10`; `test/unit/transactions_repository_test.dart:106`; `test/widget_test.dart:16` | The test suite doesn't compile. | A typedef that refers to itself, a wrong record field, the default counter template. | Zero automated regression protection. | `flutter test` → compilation failed. | Remove the typedef, fix the assertion, delete or replace the template test. |
| **BUG-25** | MEDIUM | `spending_trends_provider.dart:26-45` | The 6-month trend chart shows this month's totals divided by 6 for each month. | Placeholder code. | Financially misleading chart. | Any user with data. | Query per month, or hide the chart until it's implemented. |
| **BUG-27** | HIGH (deployment) | `firebase.json` hosting headers | `Cache-Control: max-age=31536000` on `**/*.js`, but Flutter's `main.dart.js`/`flutter_bootstrap.js` have fixed names (verified in a `build/web` listing). | Cache headers written as if file names were content-hashed. | After a deploy, users can keep running the old app for up to a year (particularly once the service worker is bypassed or reset). Bug fixes won't reach users. | Deploy v1, then v2 → returning browsers may load the cached `main.dart.js`. | Use `no-cache` for `index.html`, `main.dart.js`, `flutter_bootstrap.js`, `flutter_service_worker.js` and `version.json`; keep long caching only for versioned assets. |
| **BUG-22** | LOW | `navigation_rail_sidebar.dart:151` | Undefined `authNotifierProvider` (compile error; the file is dead code). | Missing import. | Analyzer error; it would break the build if the file were ever imported. | `flutter analyze`. | Fix the import or delete the unused shell. |
| **BUG-23** | LOW | `transactions_repository_impl.dart:50-54` | A second `catch (e, stackTrace)` after `catch (e)` is dead code, and the first one doesn't log. | Copy-paste. | Errors from `getTransactions` aren't logged. | — | Remove the first `catch`. |
| **BUG-24** | LOW | `transaction_card.dart:31, 191`; `transaction_detail_modal.dart:183` | Transfers/loans show category "Unknown" and are coloured as expenses. Each card fetches its category separately. | Placeholder category ids `'transfer'`/`'loan'`; colour chosen by `isIncome`. | Confusing display; extra reads. | View a transfer in the list. | Special-case these types in the display logic. |

(BUG-07 is in §7 because it's highly likely rather than executed.)

## 7. Potential Bugs / Risks

| ID | Severity | Location | Risk | Confidence |
|---|---|---|---|---|
| **BUG-07** | HIGH | `loan_metadata.g.dart:38`, `build.yaml:19`, `loan_transaction_form.dart:123,137` | `LoanMetadata.toJson()` returns `installments` as a list of `LoanInstallment` objects (not maps). The Firestore SDK rejects values it doesn't recognise, so creating a loan with installments is expected to fail. The failure is hidden by BUG-04. | Highly likely (generated code confirmed; write not executed) |
| R-01 | MEDIUM | `edit_transaction_modal.dart`, `add_edit_transaction_page.dart` (category/account dropdowns) | When editing a transaction whose category is `'transfer'`/`'loan'` or inactive/deleted, or whose account is inactive, the dropdown value isn't among its items. That triggers a Flutter assertion in debug builds and shows an empty field in release. | Likely |
| R-02 | MEDIUM | Forms call `ref.read(transactionsNotifierProvider.notifier)` from dialogs where nothing watches it (auto-dispose) | Each call builds the notifier, which triggers a full list load (extra reads). The notifier may also be disposed mid-operation. | Potential |
| R-03 | MEDIUM | `transfer_service.dart:67` | The insufficient-balance check also applies to `creditCard` accounts, which are normally allowed to go negative. | Potential — confirm the business rule (Q-3) |
| R-04 | LOW | All models | Money is `double`; sums are done in floating point (`getTotalByType`, balance maths). Rounding drift over many transactions. | Potential |
| R-05 | LOW | All date handling | Local `DateTime` stored as `Timestamp`; month ranges built in local time. Users in different timezones or devices see transactions shift across month boundaries. | Potential |
| R-06 | MEDIUM | `*_model.dart` `fromFirestore` | Hard casts (`data['name'] as String`, `(data['amount'] as num)`) crash a whole list if any single document is malformed (for example the test seed account type `'bank'` is tolerated, but a missing field isn't). | Potential |
| R-07 | LOW | `loan_service.dart:17-60` | `getActiveLoans` reads *all* loans (no limit) and is called several times per dashboard render (active, owed, owe, overdue providers). | Confirmed code, impact scales with data |
| R-08 | LOW | `LoanStatus.overdue` | Declared and rendered, but never stored. Queries by status would miss overdue loans. | Confirmed |
| R-09 | MEDIUM | `auth_remote_datasource.dart:125-162` | `GoogleSignIn.signIn()` is the legacy web flow; on newer Google Identity Services it may not return an `idToken`. Needs verification on the target domain. | Unknown |
| R-10 | LOW | `app_router.dart:31` | `debugLogDiagnostics: true` prints every route to the browser console in production. | Confirmed |

---

## 8. Security Findings

| ID | Severity | Finding | Evidence | Action |
|---|---|---|---|---|
| S-01 | — (positive) | Owner-only isolation is enforced server-side for every path; there's a default-deny catch-all; hard deletes are denied; `createdBy == auth.uid` is checked on create. | `firestore.rules`, `storage.rules` | Keep. |
| S-02 | HIGH | User-document rule and client model don't match (BUG-05). | `firestore.rules:25-27`, `user_model.dart:36-47` | Align them and verify the deployed rules. |
| S-03 | MEDIUM | Rules don't validate types or values. An owner can write any `currentBalance`, `amount`, `type`, change `createdBy` on update, or un-delete. The risk is limited to the user's own data, but it undermines integrity and any future sharing. | `firestore.rules` accounts/categories/transactions `allow update: if isOwner(userId)` | Add schema and immutable-field checks (`createdBy`, `createdAt`). Consider a Cloud Function for balance writes. |
| S-04 | MEDIUM | No security headers: no CSP, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy` or `Permissions-Policy`, so the app can be framed (clickjacking). | `firebase.json` hosting headers | Add headers in `firebase.json`. |
| S-05 | LOW | Email verification is never enforced; unverified accounts have full access. | §3 A5 | Decide on the policy (Q-5). |
| S-06 | LOW | `storage.rules` `profiles/{uid}/*` is readable by any signed-in user (all other paths are owner-only). Unused today. | `storage.rules` | Tighten it when profiles are built. |
| S-07 | INFO | Client configuration: `lib/firebase_options.dart` is gitignored (`.gitignore:47`) and not in the repo. `web/index.html:25` contains the Google OAuth web client id, and `firebase.json` contains the Firebase project id and web app id. These are public identifiers by design, not secrets. No private keys, service accounts or `.env` files were found in the repo. | — | Restrict the API key to the hosting domain in Google Cloud. Enable **App Check** (not configured). |
| S-08 | LOW | Debug logging includes emails and uids (`LoggerService.info`), but only when `kDebugMode`. Warnings and errors (which may include exception text) are logged in release. Router diagnostics are on (R-10). | `logger_service.dart`, `app_router.dart:31` | Turn off `debugLogDiagnostics` in release. |
| S-09 | LOW | No re-authentication, password change, or account/data deletion flow. | — | Potential requirement (Q-6). |
| S-10 | INFO | Injection: no raw query strings or HTML rendering; Firestore parameterised queries only. No findings. | — | — |

Roles and authorization (§3 of the brief):

| Role | Login | Dashboard | Modules | Create / Read / Update / Delete | Approval / Payment / Admin | Enforcement |
|---|---|---|---|---|---|---|
| Authenticated user | Email or Google | Yes | All | Own data only; delete is soft (hard delete denied by rules) | None exist | Firestore rules (server-side) + router guard (client). No UI-only permission checks were found. Cross-user access is blocked by `isOwner`. No privilege-escalation surface because there are no roles. **Route bypass:** routes are client-only but data access is rule-protected, so bypassing a route exposes nothing. |

## 9. Performance Findings

| ID | Severity | Finding | Evidence |
|---|---|---|---|
| PF-01 | MEDIUM | Aggregations read every document in the range, client-side: `getTotalByType` (called twice per dashboard load), `getTotalsByAccount`, and `getActiveLoans` (×3–4 providers, unbounded). | `transactions_remote_datasource.dart` `getTotalByType`/`getTotalsByAccount`; `loan_providers.dart` |
| PF-02 | LOW | Each `TransactionCard` issues its own `categoryProvider(id)` fetch. | `transaction_card.dart:31` |
| PF-03 | LOW | Transaction writes trigger `refresh()` on the list (20-document read), plus a second full load when the notifier is created on demand (R-02). | `transactions_notifier.dart` |
| PF-04 | LOW | Accounts and categories lists aren't paginated (fine at personal scale). | data sources |
| PF-05 | MEDIUM | `eazyvault_logo.png` is 1.2 MB and loaded on the splash and auth screens. | `pubspec.yaml` assets, `splash_screen.dart:82`, `auth_layout.dart:35` |
| PF-06 | LOW | Forced 3-second splash on every start and login. | BUG-12 |
| PF-07 | INFO | The release web build succeeded; icon tree-shaking is on. The renderer and bundle size weren't profiled. | build output |
| PF-08 | LOW | 129 uses of deprecated `withOpacity` inside build methods (allocations; also a future break). | analyzer |

## 10. Data Integrity Findings

| ID | Severity | Finding |
|---|---|---|
| DI-01 | CRITICAL | Wrong balance maths for transfer, loanTaken and loanRepayment (BUG-01, BUG-02). |
| DI-02 | HIGH | Non-atomic multi-document writes: transaction + balance (BUG-10); transfer balances + history record (BUG-01); `recordRepayment` + repayment transaction (`loan_repayment_form.dart:82-124`). |
| DI-03 | HIGH | Stale full-document overwrites: account edit (BUG-08); transaction edit erases metadata (BUG-03). |
| DI-04 | MEDIUM | No referential integrity: account/category deletes orphan transactions (BUG-17); placeholder category ids `'transfer'`/`'loan'` aren't real documents. |
| DI-05 | MEDIUM | No duplicate prevention: create buttons are disabled while loading, but there's no idempotency key. The retry after a partial failure duplicates (BUG-10). |
| DI-06 | LOW | Audit history: only `createdAt`/`updatedAt`/`createdBy`; no change log for financial edits. Soft delete keeps records (good). |
| DI-07 | — | Existing production data (if any) may already contain wrong balances from DI-01. A reconciliation step (recomputing from transactions) will be needed when the maths is fixed (Q-2). |

## 11. UX Findings

- **Good:** consistent snackbars, confirmation dialogs before deletes, loading spinners on submit buttons, `EmptyState`/`ErrorView` on the account, category and transaction lists, dark mode.
- **Issues:**
  - False success on transfer/loan (BUG-04).
  - Dead buttons: search, filter, 4 loans-card actions.
  - Broken category navigation (BUG-06).
  - Duplicate create UIs behave differently. `AddAccountModal` vs `AddEditAccountPage`; `AddTransactionDialog` (rejects 0) vs `AddEditTransactionPage` (accepts 0).
  - No persistent navigation (P1).
  - Deep links and refresh are lost (BUG-12).
  - Misleading trend chart (BUG-25).
  - The "Remember me" label implies session persistence (A6).
  - Accessibility not addressed beyond Material defaults. Keyboard navigation relies on Material widgets. Not tested.

## 12. Code Quality Findings

`flutter analyze` (after `build_runner`): **1,278 issues: 47 errors, 200 warnings, 1,031 infos.**

| Category | Count / detail |
|---|---|
| Errors | 38 `argument_type_not_assignable` + `non_bool_condition` (strict-casts on `dynamic` in `add_transaction_dialog.dart`, `add_edit_transaction_page.dart`, `transactions_page.dart`, `categories_modal.dart`), missing `firebase_options.dart` (2), `navigation_rail_sidebar.dart:151`, tests (4). **Analyzer-only for strict-casts; the release web build compiles.** |
| Deprecated APIs | 135 (`withOpacity` 129, `value` 6) |
| Unused imports | 25 |
| Unused locals/fields | 6 (`accounts_modal.dart:34`, `categories_modal.dart:50`, `dashboard_header.dart:38`, `spending_trends_chart.dart:272`, `transactions_modal.dart:224`, `error_boundary.dart:22`) |
| Unawaited futures | `account_detail_page.dart:58`, `transaction_detail_page.dart:61` |
| Lint noise | `always_use_package_imports` 500 (the code uses relative imports), `avoid_dynamic_calls` 156, `always_put_required_named_parameters_first` 62 |
| Unused dependencies | `firebase_storage`, `cached_network_image`, `shimmer`, `uuid`, `image_picker`, `file_picker`, `path_provider`, `connectivity_plus`, `url_launcher`, `flutter_svg`; `flutter_lints` is redundant with `very_good_analysis`; `mockito` is unused |
| Dead code | Navigation shell (3 files), `AccountBalancesCard`, `PageTransitions`/`ShimmerLoading`, `LoanRepaymentForm` (unreachable), `TransferService.reverseTransfer`, `AssetConstants` SVG paths (files don't exist) |
| Duplicate logic | Two account-create UIs, two category-create UIs, three income/expense forms (`AddTransactionDialog`, `AddEditTransactionPage`, `EditTransactionModal`), five delete-transaction handlers with slightly different invalidation |
| Oversized widgets | `transactions_modal.dart` 644 lines, `dashboard_page.dart` 596, `dashboard_header.dart` 577, `loan_repayment_form.dart` 515 |
| Inconsistencies | `transferServiceProvider`/`loanServiceProvider` use `FirebaseFirestore.instance` instead of `firebaseFirestoreProvider` (hurts testability). Services call Firestore directly from the domain layer. Forms catch raw exceptions from services but use `Failure` from repositories. |
| Misleading docs | The repo-root `*_SUMMARY.md` files claim 100% completion and passing tests; neither is true. |

## 13. Test Coverage

- **Unit:** 17 tests in 2 files (`account_balance_service_test.dart` 8, `transactions_repository_test.dart` 9), using `fake_cloud_firestore`. **They don't compile** (BUG-21), so effective coverage is 0.
- **Widget:** only the default counter template (broken).
- **Integration / e2e:** none. **Rules tests** (emulator): none.
- The existing balance tests assert the current income-vs-everything-else behaviour, so they wouldn't catch BUG-02.

| Feature | Existing test | Missing test | Priority |
|---|---|---|---|
| Balance effect per `TransactionType` (create/update/delete) | Income/expense only (not compiling) | loanGiven, loanTaken, loanRepayment (both directions), transfer; account change on update | P0 |
| Transfer (atomicity, both accounts, delete/reverse) | None | Service + form flow | P0 |
| Loan create with installments (serialization) | None | Write `LoanMetadata` with installments to Firestore | P0 |
| Loan repayment status transitions | None | pending→partial→completed, over-repayment rejected | P1 |
| Transaction edit preserves metadata | None | Edit of a loan/transfer | P0 |
| Account edit (opening balance delta, no stale overwrite) | None | Repository/service | P0 |
| Firestore rules (owner isolation, `createdBy`, user doc create, delete denied) | None | `@firebase/rules-unit-testing` against the emulator | P0 |
| Auth sign-up/sign-in (user doc creation, error mapping) | None | With `firebase_auth_mocks` | P1 |
| Router redirect / deep link | None | Widget test of the redirect | P1 |
| Soft delete filtering on all queries | Partial (repository delete) | Accounts/categories/getAccount | P2 |
| Transaction filters + pagination | Partial (getTransactions) | Combined filters, `loadMore`, date bounds | P2 |
| Dashboard aggregates (month stats, account financials) | None | Provider tests | P2 |
| Forms validation (amount, password) | None | `Validators` unit tests | P3 |
| Error handling (repository → `Failure` mapping) | None | Per repository | P2 |

## 14. Deployment Readiness

| Item | Status | Detail |
|---|---|---|
| Web build | OK (with config) | `flutter build web --release` succeeded on Flutter 3.32.8 using a placeholder `firebase_options.dart`. |
| Firebase config | NOT READY | `lib/firebase_options.dart` isn't committed (by design); it has to be generated with `flutterfire configure`. `flutterfire` CLI isn't installed on this machine. |
| Firebase project / environments | NOT READY | Only `eazy-vault-dev` (in `firebase.json`). **No `.firebaserc`**, so `firebase deploy` has no project unless `--project` is passed. No separate production project, flavors or `--dart-define`. |
| Hosting | PARTIAL | SPA rewrite OK. Hash URLs so refresh works at the HTTP level, but the app redirects to the dashboard (BUG-12). Cache headers risk stale builds (BUG-27). No security headers (S-04). |
| Rules / indexes | PARTIAL | Rules and indexes are in the repo; the deployed state is unknown (Q-1). Missing composite indexes (BUG-13). An unused `sortOrder` index. |
| Debug flags | PARTIAL | `debugLogDiagnostics: true` (R-10). Crashlytics/Analytics only initialised when `!kDebugMode` (correct), but Crashlytics doesn't work on web. |
| Error monitoring | NOT READY | None effective (BUG-11). |
| Source maps | Default (none emitted) | Consider `--source-maps` plus private upload if a monitoring tool is added. |
| CI/CD | MISSING | No workflow files. |
| CORS | N/A | No custom APIs; only Firebase SDK calls. |

## 15. Production Blockers (P0)

| ID | Category | Description | Why it matters | Affected area | Suggested action |
|---|---|---|---|---|---|
| P0-01 | Data integrity | Transfer double debit (BUG-01) | Wrong money | Transfers | Single atomic transfer operation |
| P0-02 | Data integrity | Loan-taken/repayment balance direction (BUG-02) | Wrong money | Loans | Per-type sign rules + tests |
| P0-03 | Data integrity | Edit erases loan/transfer metadata (BUG-03) | Data loss | Transaction edit | Block or specialise the edit; always `copyWith` |
| P0-04 | UX / integrity | False success messages (BUG-04) | Users trust unsaved data | Transfer/loan forms | Check results |
| P0-05 | Auth / security | User doc vs rules mismatch (BUG-05) | Sign-up/login show errors | Auth | Align the model and rules; verify deployment |
| P0-06 | Core feature | Category edit/detail unreachable (BUG-06) | Core CRUD broken | Categories | Fix navigation |
| P0-07 | Core feature | Loan installments save failure (BUG-07) | Feature fails | Loans | `explicit_to_json: true` or manual `toJson`; test |
| P0-08 | Data integrity | Account edit stale overwrite / opening balance ignored (BUG-08) | Lost updates | Accounts | Partial update + delta transaction |
| P0-09 | Correctness | Dashboard balances stale (BUG-09) | Wrong numbers shown | Dashboard | Refresh or stream accounts |
| P0-10 | Data integrity | Non-atomic transaction + balance writes (BUG-10) | Drift, duplicates | Transactions | One Firestore transaction |
| P0-11 | Reliability | No working error monitoring (BUG-11) | Blind in production | Platform | Web-capable reporter |
| P0-12 | Deployment | Year-long cache on non-hashed JS (BUG-27) | Fixes won't reach users | Hosting | Fix headers |
| P0-13 | Quality | Test suite doesn't compile; no tests for money or rules (BUG-21) | No regression safety for the fixes above | Tests | Fix and add the P0 tests from §13 |

Also required before launch, but decision-dependent: a production Firebase project plus `.firebaserc` (Q-7), and the loan repayment entry point (T16) if loans ship.

## 16. Recommended Fix Plan

**Phase 0 — Safety net (1–2 days)**
1. Fix the test compilation (BUG-21). Add Firestore emulator rules tests.
2. Write failing tests that pin down the *intended* balance effects per type (needs Q-2/Q-3 answers).

**Phase 1 — Money correctness (P0-01..03, 07, 08, 10)**
3. Introduce one balance-effect function per `TransactionType` and use it for create, update and delete.
4. Move transfer, loan and repayment into atomic service methods that write the transaction document and the balances in one `runTransaction`.
5. Stop generic editing of transfer/loan transactions. Always `copyWith` the existing model.
6. Account edit: partial update and opening-balance delta.
7. Fix `LoanMetadata` serialization (`explicit_to_json: true` in `build.yaml`, then regenerate).
8. Write a reconciliation script to recompute `currentBalance` from transactions for existing users (Q-2).

**Phase 2 — Broken flows and UX (P0-04..06, 09)**
9. Check results in all forms. Refresh or stream accounts after writes.
10. Fix category navigation; add delete-category UI.
11. Wire up the loan repayment entry point and the loans-card buttons, or hide them.
12. Align the user-doc rule and model; make sign-up tolerant of a failed profile write.

**Phase 3 — Operations and deployment (P0-11, 12, P1)**
13. Error monitoring, cache and security headers, `.firebaserc` and a production project, turn off `debugLogDiagnostics`.
14. Router refactor (`refreshListenable`, keep the deep link, remove the fixed splash delay).
15. Add the missing indexes or client-side filtering; fix the custom date range end.

**Phase 4 — Cleanup (P2/P3)**
16. Remove dead code and unused dependencies, merge duplicate forms, fix the analyzer errors, replace the fake trend chart.

## 17. Technical Debt

- Duplicate UIs (account ×2, category ×2, income/expense ×3, delete handlers ×5).
- Dead navigation shell, unused widgets and helpers, unused dependencies (§12).
- Domain services call Firestore directly and bypass DI (`FirebaseFirestore.instance`).
- The router is rebuilt per auth event.
- The `Failure` pattern isn't used by services, which throw instead.
- Error states replace entire lists.
- Money stored as `double`; local-time dates.
- 1,278 analyzer issues, including 135 deprecations.
- `metadata` is an untyped map with typed wrappers; nested JSON config gap.
- `sortOrder` index without a field; `AssetConstants` pointing at missing files; `assets/` directory not declared in `pubspec.yaml`.
- Out-of-date status/summary markdown files in the repo root.

## 18. Questions / Unknowns

- **Q-1** What are the currently deployed Firestore/Storage rules and indexes? Are they identical to the repo? This decides whether BUG-05 happens in the live environment.
- **Q-2** Is there real user data in `eazy-vault-dev` (or elsewhere)? If so, should balances be recomputed after the maths is fixed?
- **Q-3** Intended balance rules:
  - Should credit-card accounts be allowed a negative opening balance, or to go negative via transfers?
  - For a `loanRepayment`, should direction follow the original loan (received for `loanGiven`, paid for `loanTaken`)?
- **Q-4** Should transfers and loans count toward "monthly income/expense" and the per-account chart, or be excluded (as now)?
- **Q-5** Should email verification be required before using the app?
- **Q-6** Are profile, settings (theme toggle), account deletion, data export, attachments and offline support in scope for launch?
- **Q-7** Which Firebase project and domain is production? Is there a separate prod project, and what's the intended CI/deploy process?
- **Q-8** Which error-monitoring tool is acceptable (Crashlytics doesn't support web)?
- **Q-9** Is Google Sign-In working on the current hosting domain (authorised origins, client id)?

## 19. Detailed Evidence

Key code locations, for verification:

- **Balance direction:** `lib/features/transactions/domain/services/account_balance_service.dart:36-38` (`transaction.isIncome ? +amount : -amount`), `:78-88` (update), `:138-140` (revert). `TransactionType.affectsBalance` (`transaction_type.dart`) exists but is never used.
- **Transfer double call:** `lib/features/transactions/presentation/widgets/transfer_transaction_form.dart:74` (`transferService.createTransfer`) then `:110` (`transactionsNotifier.createTransaction(transaction)` with `type: TransactionType.transfer, accountId: _fromAccountId`) → `transactions_repository_impl.dart:89` (`updateBalanceForNewTransaction`).
- **Ignored results:** `transfer_transaction_form.dart:110→117`, `loan_transaction_form.dart:144→151`, `loan_repayment_form.dart:124→135`.
- **Metadata dropped on edit:** `edit_transaction_modal.dart:126-146` and `add_edit_transaction_page.dart:128-147` construct `TransactionModel(...)` without `metadata:`; `transactions_remote_datasource.dart` `updateTransaction` → `.update(updatedTransaction.toFirestore())` (which includes `'metadata': metadata`).
- **Nested JSON:** `lib/features/transactions/domain/models/loan_metadata.g.dart:38` `'installments': instance.installments,`; `build.yaml:19` `explicit_to_json: false`.
- **Unreachable repayment:** `grep -rn "LoanRepaymentForm(" lib` → only its own constructor declaration (`loan_repayment_form.dart:18`).
- **User doc vs rules:** `firestore.rules:25-27` (`hasRequiredFields(... ['createdAt','updatedAt','createdBy'])`); `lib/features/authentication/data/models/user_model.dart:36-47` (no `createdBy`); `auth_remote_datasource.dart:79,114,154` → `_createUserDocument` `:258-284`.
- **Category route:** `lib/core/constants/app_constants.dart` `categoryDetail = '/categories/:id'`; `lib/core/router/app_router.dart` registers only `/categories`, `/categories/add`, `/categories/:id/edit`; navigation at `categories_page.dart:160-162`, `categories_modal.dart:268-272`.
- **Account stale write:** `add_edit_account_page.dart:98` `currentBalance: _existingAccount?.currentBalance ?? openingBalance`; `accounts_remote_datasource.dart:98` `.update(updatedAccount.toFirestore())`.
- **Dashboard staleness:** `accounts_notifier.dart` (`totalBalance` computed from the `AccountsNotifier` state, loaded via `getAccounts` `get()`); invalidations at `add_transaction_dialog.dart:126-128`, `dashboard_page.dart:136-140`, `:543-546` never touch `accountsNotifierProvider`.
- **Crash handlers:** `firebase_service.dart:36,40` → overwritten by `main.dart:23,31` → `error_boundary.dart:28`.
- **Router:** `app_router.dart:25-31` (`ref.watch(authStateChangesProvider)` inside the provider building `GoRouter(initialLocation: RouteConstants.splash, debugLogDiagnostics: true)`); `splash_screen.dart:49-58`.
- **Search no-op:** `transactions_notifier.dart:79-87` (the `getTransactions` call has no `searchQuery`); `transactions_remote_datasource.dart` has no `searchQuery` parameter.
- **Indexes:** `firestore.indexes.json` — transactions indexes cover `isDeleted` + at most one of `type`/`accountId`/`categoryId` + `date`.
- **Hosting:** `firebase.json` headers `**/*.@(js|css)` → `max-age=31536000`; `build/web` contains unhashed `main.dart.js`, `flutter_bootstrap.js`, `flutter.js`, `flutter_service_worker.js`. No `.firebaserc` in the repo root.
- **Tests:** `test/helpers/mock_firebase.dart:6` `typedef FakeFirebaseFirestore = FakeFirebaseFirestore;`; `test/unit/transactions_repository_test.dart:106` `result.transactionId`; `test/widget_test.dart:16` `MyApp`.
- **Dead nav shell:** `grep -rln AppScaffold lib` → only its own file; `navigation_rail_sidebar.dart:151` undefined `authNotifierProvider`.
- **Commands run:**
  - `flutter pub get`
  - `dart run build_runner build --delete-conflicting-outputs` (145 outputs; generated files are gitignored)
  - `flutter analyze` (1,278 issues, 47 errors)
  - `flutter test test/unit` (compilation failed)
  - `flutter build web --release` with a temporary placeholder `lib/firebase_options.dart` (succeeded; placeholder and `build/` removed afterwards)
