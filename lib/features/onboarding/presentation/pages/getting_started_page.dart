import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../domain/onboarding_steps.dart';
import '../providers/onboarding_notifier.dart';

/// "How EazyVault Works" — a short, swipeable walkthrough shown the first
/// time a user chooses "Show Me How" from the Welcome dialog, or any time
/// afterward from Settings/the dashboard. The last page is a distinct
/// "You're Ready" screen rather than another Back/Next step.
class GettingStartedPage extends ConsumerStatefulWidget {
  const GettingStartedPage({super.key});

  @override
  ConsumerState<GettingStartedPage> createState() => _GettingStartedPageState();
}

class _GettingStartedPageState extends ConsumerState<GettingStartedPage> {
  final _controller = PageController();
  int _page = 0;

  // +1 for the final "You're Ready" screen.
  int get _pageCount => onboardingSteps.length + 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _markSeen() {
    ref.read(hasSeenGettingStartedNotifierProvider.notifier).markSeen();
  }

  void _finish() {
    _markSeen();
    context.go(RouteConstants.dashboard);
  }

  void _skip() {
    _markSeen();
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go(RouteConstants.dashboard);
    }
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _back() {
    _controller.previousPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _page == _pageCount - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Getting Started'),
        actions: [
          if (!isLastPage)
            TextButton(
              onPressed: _skip,
              child: const Text('Skip'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.paddingMD,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: (_page + 1) / _pageCount,
                    minHeight: 4,
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                ),
                AppSpacing.gapMD,
                Text(
                  '${_page + 1} of $_pageCount',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pageCount,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                if (index < onboardingSteps.length) {
                  return _StepView(step: onboardingSteps[index]);
                }
                return _ReadyView(
                  onGoToDashboard: _finish,
                  onOpenManual: () {
                    _markSeen();
                    context.push(RouteConstants.userManual);
                  },
                );
              },
            ),
          ),
          if (!isLastPage)
            Padding(
              padding: AppSpacing.paddingMD,
              child: Row(
                children: [
                  if (_page > 0)
                    OutlinedButton(onPressed: _back, child: const Text('Back'))
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: _next,
                    child: Text(
                      _page == _pageCount - 2 ? 'Finish' : 'Next',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLG,
      child: ResponsiveContent(
        maxWidth: Breakpoints.formMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.icon,
                size: 48,
                color: context.colorScheme.onPrimaryContainer,
              ),
            ),
            AppSpacing.gapLG,
            Text(
              step.title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMD,
            Text(
              step.body,
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (step.example != null) ...[
              AppSpacing.gapLG,
              Container(
                width: double.infinity,
                padding: AppSpacing.paddingMD,
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: AppSpacing.borderRadiusMD,
                ),
                child: Text(
                  step.example!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.onGoToDashboard, required this.onOpenManual});

  final VoidCallback onGoToDashboard;
  final VoidCallback onOpenManual;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppSpacing.paddingLG,
      child: ResponsiveContent(
        maxWidth: Breakpoints.formMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: context.colorScheme.primary,
            ),
            AppSpacing.gapLG,
            Text(
              "You're Ready",
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapMD,
            Text(
              'Start with your accounts, record your transactions, and '
              'let EazyVault organize the rest.',
              style: context.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapXL,
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGoToDashboard,
                child: const Text('Go to Dashboard'),
              ),
            ),
            AppSpacing.gapSM,
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onOpenManual,
                child: const Text('Open User Manual'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
