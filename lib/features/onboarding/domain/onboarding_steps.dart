import 'package:flutter/material.dart';

/// Content for one page of the Getting Started walkthrough. Kept as plain
/// data (not individual widgets) so the copy is easy to review/edit in one
/// place — mirrors how `user_manual` content is structured.
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.icon,
    required this.body,
    this.example,
  });

  final String title;
  final IconData icon;
  final String body;
  final String? example;
}

/// The 9 core steps plus a "More Tools" round-up. The final "You're Ready"
/// screen isn't in this list — it has its own distinct call-to-action
/// buttons (see `GettingStartedPage`), not just Back/Next.
///
/// Each step is a concrete navigation walkthrough — where to tap, what to
/// fill in, what to tap next — not just a description of the feature. The
/// order follows the sequence a new user actually needs: an account to
/// hold money, categories to label it, then expense/income/transfer entry,
/// before the optional extras (loans, budgets, recurring rules).
///
/// Content here is deliberately scoped to what EazyVault actually does
/// today: budgets are a category + monthly limit (no custom period),
/// "bills" are loan due dates surfaced on the dashboard rather than a
/// separate bill-tracking feature, and recurring rules support Daily/Weekly/
/// Monthly only. Only features with a working UI entry point are covered —
/// CSV import has real code behind it but no reachable screen yet, so it's
/// left out entirely rather than mentioned as "coming soon."
const List<OnboardingStep> onboardingSteps = [
  OnboardingStep(
    title: '1. Add Your First Account',
    icon: Icons.account_balance_wallet_outlined,
    body: 'From the dashboard, tap Accounts under Quick Actions (or the '
        'Accounts tab), then tap the + button. Enter a Name, choose a '
        'Type — Cash, Savings, Current, UPI or Credit Card — and enter '
        'the Opening Balance: what that account holds right now. You '
        "can't change this later, so get it right the first time. Tap "
        'Save.',
    example: 'HDFC Bank — Savings — ₹50,000',
  ),
  OnboardingStep(
    title: '2. Set Up Your Categories',
    icon: Icons.category_outlined,
    body: 'Tap Categories under Quick Actions (or the Categories tab). '
        'First time here? Tap Load Defaults to add a starter set of '
        'common Income and Expense categories instantly. Want your own '
        'instead — or in addition? Tap + Add Category, give it a Name, '
        'choose Income or Expense, pick a Color and Icon, then tap Save.',
    example: 'Defaults: Food, Transport, Shopping · Salary, Freelance',
  ),
  OnboardingStep(
    title: '3. Record Your First Expense',
    icon: Icons.remove_circle_outline,
    body: 'Tap Add Expense under Quick Actions (or the + button on the '
        'dashboard). Choose the Account the money left and a Category, '
        'enter the Amount and Date, then tap Add Expense. Description '
        'and Vendor are optional.',
    example: 'Food → ₹450 from Cash, 3 Oct',
  ),
  OnboardingStep(
    title: '4. Record Income — and Set "Income For"',
    icon: Icons.add_circle_outline,
    body: 'Tap Add Income under Quick Actions. Choose the Account and '
        'Category, enter the Amount and the Credited Date — when the '
        'money actually arrived. Then check "Income For": it defaults '
        "to the credited date's month, but you can pick a different "
        'month if this income should count toward another reporting '
        'period — for example, salary credited on 30 September but '
        "meant to count as October's income. Tap Add Income to save.",
    example: 'Salary → ₹75,000, Credited 30 Sep, Income For: October',
  ),
  OnboardingStep(
    title: '5. Transfer Between Accounts',
    icon: Icons.swap_horiz,
    body: 'Tap Transfer under Quick Actions. Choose a From Account and a '
        'To Account — they must be different — enter the Amount and '
        'Date, then tap Transfer. Both balances update immediately.',
    example: 'Cash → HDFC Bank, ₹2,000',
  ),
  OnboardingStep(
    title: '6. Track Money Lent or Borrowed',
    icon: Icons.handshake_outlined,
    body: 'Tap Lend or Borrow under Quick Actions. Enter the other '
        "person's Name, the Amount, the Account it moves through, and "
        'an optional Due Date. Anything with a due date shows up under '
        '"Upcoming Bills" on your dashboard so it doesn\'t sneak up on '
        'you. Record a Repayment any time from the Loans & Debts card '
        "to update what's left.",
    example: 'Lend to Raj — ₹5,000, due in 30 days',
  ),
  OnboardingStep(
    title: '7. Set a Budget',
    icon: Icons.savings_outlined,
    body: 'Tap Budgets under Quick Actions, then + Add Budget. Pick an '
        'expense Category and set a Monthly Limit, then tap Save. '
        "EazyVault tracks what you've spent against it automatically "
        'and can alert you as you approach or cross the limit.',
    example: 'Food Budget: ₹10,000/month',
  ),
  OnboardingStep(
    title: '8. Automate Recurring Money',
    icon: Icons.repeat,
    body: 'Tap Recurring under Quick Actions, then + Add. Choose Income '
        'or Expense, the Account, Category, Amount, how often it '
        'Repeats — Daily, Weekly or Monthly — and a Start Date, then '
        'tap Save. EazyVault creates those transactions automatically, '
        'even catching up on any you missed since you last opened the '
        'app.',
    example: 'Salary → Monthly   ·   Rent → Monthly',
  ),
  OnboardingStep(
    title: '9. See Your Financial Progress',
    icon: Icons.insights_outlined,
    body: 'Your dashboard — the first screen you land on — brings it '
        'all together: total balance, this month\'s income and '
        'expenses, account breakdown, net worth and spending-trend '
        'charts, budget progress, your loans summary and upcoming '
        'bills, all in one scroll.',
  ),
  OnboardingStep(
    title: 'More Tools',
    icon: Icons.apps_outlined,
    body: 'A few more things worth knowing:\n\n'
        '• Receipts & Photos — open a transaction\'s detail view and '
        'tap Add Attachment to attach a receipt or photo to it.\n\n'
        '• Notifications — turn on browser alerts for bills and budgets '
        'from Profile & Settings; the in-app bell always shows them '
        'too.\n\n'
        '• Profile & Settings — tap your name/avatar on the dashboard '
        'to update your display name and manage alerts.\n\n'
        '• Need help later? Open the User Manual any time from the '
        'dashboard or Profile & Settings.',
  ),
];
