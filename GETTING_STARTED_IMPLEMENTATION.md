# Getting Started Onboarding + User Manual — Implementation Notes

## Login trigger

The Welcome dialog is triggered from `DashboardPage.build()` — the dashboard is already the
post-login landing page for every sign-in path (email/password, Google, and returning sessions via
the router's redirect logic), so it's the one place guaranteed to run once per session regardless
of how the user got there.

```dart
ref.listen<AsyncValue<bool>>(hasSeenGettingStartedNotifierProvider, (previous, next) {
  next.whenOrNull(
    data: (hasSeen) {
      if (hasSeen) return;
      _showWelcomeDialog(context, ref);
    },
  );
});
```

`hasSeenGettingStartedNotifierProvider` resolves asynchronously (it awaits `SharedPreferences`), so
this callback always runs after `build()` has already returned — not mid-build — which is why
calling `showDialog` directly from it is safe. This mirrors the existing recurring-transactions
catch-up listener a few lines above it in the same file, which does the same thing for a different
one-time, post-build side effect.

## First-time user detection

There's no separate "first login" signal — `hasSeen` being `false` (its default) is the only
check. It's `true` after `markSeen()` has ever been called, which happens:

- When either button on the Welcome dialog is pressed ("Show Me How" or "Skip for Now" — both
  mark it seen; only "Show Me How" also navigates to the walkthrough).
- When the user exits the Getting Started page via Skip, Finish, or "Go to Dashboard" on the final
  screen.

## Preference storage

**Decision: `SharedPreferences`, not a new Firestore field.**

Before adding anything, the existing user-preference mechanisms were inspected:

- `UserModel` / the Firestore `users/{uid}` document — holds identity fields only (email,
  displayName, photoUrl, timestamps, emailVerified). No settings/preferences block exists there.
- The actual precedent for "has the user already dismissed/configured this thing" in this app is
  **local, not Firestore**: `AuthLocalDataSource` already stores `rememberMe`/`lastEmail`, and
  `NotificationsLocalDataSource` already stores `notificationsEnabled`, both via
  `SharedPreferences` with their own small datasource + `@Riverpod(keepAlive: true)` DI provider +
  notifier.

`hasSeenGettingStarted` follows that exact established pattern instead of introducing a new
Firestore field or a new kind of preferences store:

```
lib/features/onboarding/
  data/datasources/onboarding_local_datasource.dart   # getHasSeenGettingStarted / set...
  presentation/providers/onboarding_providers.dart    # DI: SharedPreferences -> datasource
  presentation/providers/onboarding_notifier.dart     # HasSeenGettingStartedNotifier (build + markSeen)
  presentation/widgets/welcome_dialog.dart
  presentation/pages/getting_started_page.dart
  domain/onboarding_steps.dart                        # the 8 step + "More Tools" content, as data
```

New constant: `AppConstants.sharedPrefsHasSeenGettingStarted` (`app_constants.dart`), alongside the
existing `sharedPrefsRememberMe`/`sharedPrefsNotificationsEnabled` keys.

**Known limitation of this choice**: the preference is per-device/per-browser, not per-account. A
different browser or device shows the Welcome prompt again even for a returning user. This is the
same limitation `rememberMe` already has, and is called out explicitly rather than silently
accepted — see `PHASE_1_PRODUCTION_READINESS.md`.

## Navigation

New routes (`RouteConstants` / `app_router.dart`):

| Route | Page |
|---|---|
| `/getting-started` | `GettingStartedPage` |
| `/manual` (optional `?section=<id>`) | `UserManualPage` |

Both are plain `GoRoute`s outside the bottom-nav/rail `ShellRoute` (like `/reports`, `/profile`,
`/about`) — they're reached by `context.push`, so the back button/browser back works normally, and
they don't compete for one of the 4 fixed shell tabs.

Reachable from:
- The Welcome dialog ("Show Me How" → `/getting-started`).
- The dashboard's Quick Actions grid ("User Manual" tile — this replaced the "Import" tile that
  used to sit there, per the request to remove Import's UI everywhere).
- Profile & Settings → a new "Help" section with "Getting Started" and "User Manual" rows, next to
  the existing "About Us" row.
- The Getting Started page's own final screen ("Open User Manual").
- One contextual link: the Budgets modal's "Learn how budget alerts work →" opens
  `/manual?section=budgets`.

## Screens

`GettingStartedPage` is a `PageView` over `onboardingSteps` (9 entries, after a later revision —
see below) plus one extra page: a distinct "You're Ready" screen with its own two buttons
(`Go to Dashboard` / `Open User Manual`) rather than another generic Back/Next step, per the spec.
A `LinearProgressIndicator` + "X of N" text sits above the pages; Back/Next buttons sit below
(hidden on the final screen, which has its own CTAs instead); a "Skip" action lives in the
`AppBar` on every page except the last. The page count is computed from the content list's length
(`onboardingSteps.length + 1`), so adding/removing a step never needs a manual count update.

The content in `onboarding_steps.dart` went through two passes. The first draft described each
feature in the abstract ("Record Your Money", "Organize Your Spending"). It was then rewritten as
a **concrete, click-by-click navigation walkthrough** — which button to tap, which fields to fill
in, in the order a new user actually needs: account → categories (defaults vs. custom) → expense
entry → income entry (with an explicit walkthrough of the "Income For" field) → transfers →
loans/bills → budgets → recurring rules → dashboard overview → More Tools. "Track What's Due" was
folded into the loans step rather than kept separate, since bills are just loan due dates, not a
distinct feature.

Content is deliberately scoped to what EazyVault actually does today, verified against the code
rather than assumed:

- **Budgets**: "a monthly limit on an expense category" — there's no custom period or configurable
  threshold; EazyVault's built-in alert points are 80/90/100%.
- **Bills**: no separate bill-tracking feature exists. "Upcoming Bills" is the dashboard's derived
  view of loan due dates, and the walkthrough folds "what's due" into the Lend/Borrow step instead
  of implying a standalone bills feature.
- **Recurring Transactions**: Daily/Weekly/Monthly only (no yearly/custom interval); catch-up runs
  once per app session on dashboard build, not as a server-side job.
- **Account opening balance**: described as fixed once the account is created (the edit form
  disables that field) — an early draft incorrectly said it could be adjusted later as a delta;
  caught and corrected against `add_edit_account_page.dart`.
- **CSV Import**: left out entirely, from both the walkthrough and the User Manual — it has real
  backend code but no reachable screen right now (its quick-action button and route were removed
  per this same change), so it doesn't belong in user-facing docs even as "coming soon."

## User Manual structure

`lib/features/user_manual/domain/manual_content.dart` holds the content as plain data
(`ManualSection` → list of `ManualEntry`), not as hand-built widgets per section — the same idea as
`onboarding_steps.dart`, and explicitly not a new content-management system. 14 sections, following
the spec's table of contents minus a dedicated CSV Import section (dropped — see "Content
accuracy" below). Each section was fact-checked against the actual implementation (budgets, bills,
recurring, loans, notifications, reports/net worth, attachments, accounts/transactions/categories
were all re-verified in the code before writing their copy).

`UserManualPage` picks a layout from `context.isMobile`:
- **Desktop/tablet**: a 260px-wide section list on the left, content on the right (`Row` +
  `VerticalDivider`), reusing the same `ListTile`/`Icon` conventions as the rest of the app.
- **Mobile**: a search field followed by one `ExpansionTile` per section (collapsed by default,
  auto-expanded while searching).

**Search**: a simple client-side, case-insensitive filter over section titles + entry
headings/bodies (`_filteredSections` in `UserManualPage`). No new backend/search infrastructure, as
instructed — it's a substring filter over an in-memory `const` list. On desktop, searching
replaces the normal section view with a flat, labeled list of matching entries across all sections;
on mobile it filters/auto-expands the existing section list.

**Contextual help**: one link was added — "Learn how budget alerts work →" in the budget
create/edit modal, opening `/manual?section=budgets` — per the spec's explicit example and its
"only where users may reasonably need clarification" guidance. More links can be added the same
way (`context.push('${RouteConstants.userManual}?section=<id>')`) if specific pain points show up.

## Content accuracy

Every section was checked against the real implementation rather than the original feature spec.
Four places were deliberately written to differ from what a literal reading of a generic
finance-app spec might assume, two of them caught and fixed only after an initial pass:

1. **Bills** — documented as the loan-due-date view it actually is, not a separate CRUD feature.
2. **Budgets** — documented as category + fixed monthly limit with built-in 80/90/100% thresholds,
   not a configurable period/threshold.
3. **Account opening balance** — an initial pass claimed it could be edited later as a delta
   (reading too much into the repository layer's `updateAccount` capability); re-verified against
   `add_edit_account_page.dart`, which disables that field entirely once the account exists, and
   corrected.
4. **CSV Import** — an initial pass documented it as "coming soon" in the walkthrough, the manual,
   and the FAQ. On reflection that still doesn't belong in user-facing docs: the feature has no
   reachable screen at all (its quick-action button and route were removed in this same change), so
   it was dropped entirely rather than teased. Its backend code and tests are untouched for when it
   ships later.

## Responsive behavior

Both new pages reuse existing responsive building blocks instead of introducing new ones:
`ResponsiveContent` (caps width, centers), `Breakpoints.formMaxWidth`/`context.isMobile`, and the
`SafeArea > Center > SingleChildScrollView` pattern already used by `AuthLayout` for the onboarding
step/final screens, so short/landscape viewports scroll instead of overflowing. The User Manual's
two-column desktop layout collapses to the mobile expandable-list layout at the same `isMobile`
(<600px) breakpoint `AppScaffold` already uses for its own nav-rail-vs-bottom-bar switch.

**Not independently verified**: no browser-automation tooling was available in this environment, so
these layouts were not visually confirmed in a running browser at each breakpoint — see the same
honesty note already in `PHASE_1_PRODUCTION_READINESS.md`. A manual pass in Chrome at mobile/
tablet/desktop widths, light and dark, is recommended before considering this shipped.

## Testing

- `test/unit/onboarding_notifier_test.dart` — fresh install defaults to `hasSeen == false`; calling
  `markSeen()` persists so a **new** `ProviderContainer` reading the same underlying
  `SharedPreferences` instance (simulating an app restart) sees `true`.
- `test/unit/manual_content_test.dart` — every manual section has a unique non-empty id and at
  least one entry with non-empty heading/body; every onboarding step has non-empty title/body. This
  is a content-integrity check, not a UI test — it exists so a future edit can't accidentally leave
  a section empty or introduce a duplicate id.
- Full existing suite re-run after this change: 113 tests, all passing (108 pre-existing + 5 new).
- Not added: widget tests driving the actual `GettingStartedPage`/`UserManualPage` widget trees
  (navigation taps, search filtering in a running widget). Flagged as a follow-up in
  `PHASE_1_PRODUCTION_READINESS.md` rather than claimed as done.
