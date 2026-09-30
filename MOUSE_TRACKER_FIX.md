# MouseTracker assertion fix

Date: 2026-09-30 · Branch: `feature/claude-verification`

## 1. Exact root cause

`NavigationRailSidebar` (`lib/core/widgets/navigation/navigation_rail_sidebar.dart`), the extended (desktop) rail's `leading` content, wrapped the signed-in user's name/email in `Expanded`:

```dart
Row(
  children: [
    CircleAvatar(...),
    AppSpacing.gapSM,
    Expanded(                 // <-- the bug
      child: Column(children: [Text(user.displayName), Text(user.email)]),
    ),
  ],
),
```

Flutter's `NavigationRail` (`flutter/lib/src/material/navigation_rail.dart`) places `leading` as a direct child of an internal `Column` (`Material → SafeArea → Column → [spacer, leading!, spacer, Expanded(destinations)]`) and does not itself hand `leading` a pre-computed bounded width — the rail's own width is derived from its content, not fixed ahead of time. Since `NavigationRail` was rendered as a plain (non-`Expanded`) child of the `Row` in `AppScaffold`, it received an **unbounded width constraint** from that `Row` (standard Flutter behavior: a `Row` gives non-flex children loose/unbounded width so they can report their own intrinsic size). That unbounded constraint propagates down into `leading`, where the `Expanded` above has no bounded ancestor to divide space from — an invalid combination Flutter forbids.

## 2. File(s) responsible

- `lib/core/widgets/navigation/navigation_rail_sidebar.dart` — the `Expanded` inside the extended `leading` content (pre-existing code; not something added this session).
- `lib/core/widgets/navigation/app_scaffold.dart` — the `Row(children: [NavigationRailSidebar(...), VerticalDivider(...), Expanded(child: child)])` that, for the first time, actually renders `NavigationRailSidebar` (see §7).

## 3. Problematic interaction

Signing in successfully at a tablet/desktop-width browser window (≥600px), so the router redirects from `/login` to `/dashboard` and `AppScaffold` mounts the extended (or collapsed) `NavigationRailSidebar` with a real signed-in user for the first time.

## 4. Why Flutter's MouseTracker assertion was triggered

This was reproduced live in this session (`flutter run -d chrome`) immediately after a real sign-in. The actual failure sequence, straight from the console:

1. `RenderFlex children have non-zero flex but incoming width constraints are unbounded.` — thrown for the `Row` inside `leading`, with the nearest unbounded-width ancestor identified as `AppScaffold`'s own body `Row` (`RenderFlex#74b1e`, creator chain: `Row ← KeyedSubtree ← _BodyBuilder ← MediaQuery ← LayoutId-[<_ScaffoldSlot.body>] ← CustomMultiChildLayout ← ...`).
2. That exception aborts the in-progress layout pass partway through, leaving a chain of ancestor `RenderObject`s (`RenderPhysicalModel`, `RenderSemanticsAnnotations`, several `RenderFlex`/`RenderPadding`, `_RenderInkFeatures`, `RenderPointerListener`) marked `NEEDS-LAYOUT`/`NEEDS-PAINT` without a valid `size` — each subsequently throws its own `hasSize` (`box.dart:2251`, `proxy_box.dart:2122`) assertion the moment something tries to read `.size` on it (paint, hit-testing).
3. `RendererBinding.drawFrame()` calls `MouseTracker.updateAllDevices()` after every frame (unconditionally, as long as a mouse is connected — it re-hit-tests at the last known cursor position even without new pointer movement). Hit-testing into this partially-unsized tree trips the `hasSize` assertions again from inside `updateAllDevices`'s own call stack, and that reentrant failure is what finally surfaces as `mouse_tracker.dart:203`, `!_debugDuringDeviceUpdate`.

So the `MouseTracker` assertion is a **downstream casualty**, not an independent hover/overlay bug — it is what happens when `updateAllDevices()` hit-tests a render tree that a *different*, earlier layout exception left half-built. There is no custom `MouseRegion`, `Tooltip`, `OverlayEntry`, hover-triggered `setState`/navigation, or animation anywhere in `lib/` (confirmed by an exhaustive grep across the whole app) — every hover/pointer-tracking behavior in this app comes from stock Material widgets (`NavigationRail`, `InkWell`/`ListTile`, `IconButton`), so the checklist items about custom hover/overlay/tooltip code (this fix's original brief, §2–§11) do not apply here.

## 5. Fix implemented

**`navigation_rail_sidebar.dart`** — replaced `Expanded(child: Column(...))` with `SizedBox(width: 160, child: Column(...))` around the name/email text. The `Text` widgets keep `maxLines: 1` / `overflow: TextOverflow.ellipsis`, so long names/emails still truncate instead of overflowing — the fixed width just means the row no longer needs a bounded ancestor to resolve a flex share.

**`app_scaffold.dart`** — while investigating, also moved the mobile/tablet/desktop breakpoint decision from a `LayoutBuilder` (evaluated during the *layout* phase) to `MediaQuery.sizeOf(context)` (evaluated during the normal *build* phase). This is a secondary, defensive change: `AppScaffold`'s `LayoutBuilder` swaps between entirely different chrome subtrees (`BottomNavBar` / collapsed rail / extended rail), each with their own Material/`InkWell`/`NavigationRail` hover handling. Doing that swap during layout (which can run synchronously inside the same call stack as a resize-triggered pointer event on web) is exactly the kind of "mutate the tree while `MouseTracker` might be mid-update" pattern Flutter's own docs warn about; driving it from `MediaQuery` instead routes the swap through the standard build/dispose scheduling. `AppScaffold` sits directly under each `ShellRoute` page, so `MediaQuery.sizeOf(context).width` is identical to what `LayoutBuilder`'s `constraints.maxWidth` measured — no behavior change, just a safer trigger.

## 6. Why the fix is safe

- No assertions were disabled, no error/try-catch was added, no framework file was touched.
- `SizedBox(width: 160)` is a normal, bounded-width leaf widget — it needs nothing from its ancestors, so it can never reproduce this class of bug regardless of what wraps `NavigationRail` in the future.
- The breakpoint thresholds, destination order, and visual layout of the rail/bottom nav are unchanged; only *when* (build vs. layout phase) the branch is chosen changed.
- Neither change touches business logic, Firestore, or the balance/loan/transfer code paths.

## 7. Responsive navigation changes

None beyond the `AppScaffold` timing change above (§5). The rail/bottom-nav breakpoints (600/1024) and destinations (Dashboard/Transactions/Accounts/Categories) are exactly as wired earlier this session.

## 8. Hover/overlay changes

None needed — confirmed via grep there is no custom `MouseRegion`/`Tooltip`/`OverlayEntry`/hover-triggered state change anywhere in the app.

## 9. Tests performed

- Live reproduction: `flutter run -d chrome`, signed in with a real account at a desktop-width window → captured the exact `RenderFlex unbounded width` → cascading `hasSize` → `mouse_tracker.dart:203 !_debugDuringDeviceUpdate` sequence from the console (quoted above).
- Applied the fix, confirmed `flutter analyze` shows no new errors and `flutter test` stays at 54/54.
- Relaunched `flutter run -d chrome` with the fix; **live re-verification of the sign-in → dashboard transition (with the rail actually visible) is pending a human sign-in**, since this environment has no test credentials for the `eazy-vault-dev` Firebase project — everything up to that point (analyzer, unit/widget tests, and the code-level trace matching the exact captured stack) has been verified.
- Did not attempt to synthesize OS-level mouse movement or resize the actual Chrome window to fuzz for hover-during-resize scenarios, since that would mean taking control of the machine's real cursor — the live crash captured was sufficient to pinpoint the exact widget without that.

## 10. Remaining risks

- Not yet re-verified with a live sign-in against the fixed build (see §9) — please retry signing in at a window ≥600px wide and confirm the rail renders without the assertion.
- `160` is a hand-picked safe width for the name/email column under the rail's default extended width; if `NavigationRail`'s `minExtendedWidth` is ever customized away from the Material default, this value may need revisiting (documented inline in the code).
