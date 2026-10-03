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

/// The 8 core steps plus a "More Tools" round-up. The final "You're Ready"
/// screen isn't in this list — it has its own distinct call-to-action
/// buttons (see `GettingStartedPage`), not just Back/Next.
///
/// Content here is deliberately scoped to what EazyVault actually does
/// today: budgets are a category + monthly limit (no custom period),
/// "bills" are loan due dates surfaced on the dashboard rather than a
/// separate bill-tracking feature, recurring rules support Daily/Weekly/
/// Monthly only, and CSV import is called out as coming soon rather than
/// described as available, since its UI entry points are currently hidden.
const List<OnboardingStep> onboardingSteps = [
  OnboardingStep(
    title: '1. Add Your Accounts',
    icon: Icons.account_balance_wallet_outlined,
    body: 'Add the accounts you use to manage your money — cash, bank, '
        'UPI or credit card. Enter the opening balance so EazyVault can '
        'track your financial position correctly from day one.',
    example: 'HDFC Bank — ₹50,000   ·   Cash — ₹5,000',
  ),
  OnboardingStep(
    title: '2. Record Your Money',
    icon: Icons.receipt_long_outlined,
    body: 'Log income, expenses and transfers between your accounts. '
        'Each transaction has an account, category, date, amount and an '
        'optional note or receipt attachment.',
    example: 'Food → ₹450   ·   Salary → ₹75,000',
  ),
  OnboardingStep(
    title: '3. Organize Your Spending',
    icon: Icons.category_outlined,
    body: 'Categories group your transactions so you can see where your '
        'money goes. EazyVault starts you off with common categories like '
        'Food, Transport and Shopping, and you can add your own.',
  ),
  OnboardingStep(
    title: '4. Stay Within Your Budget',
    icon: Icons.savings_outlined,
    body: 'Set a monthly spending limit on an expense category. EazyVault '
        'tracks how much of it you\'ve used and can notify you as you '
        'approach or cross the limit.',
    example: 'Food Budget: ₹10,000   ·   Spent: ₹8,500   ·   Remaining: ₹1,500',
  ),
  OnboardingStep(
    title: '5. Track What\'s Due',
    icon: Icons.event_outlined,
    body: 'Money you\'ve lent or borrowed with a due date shows up under '
        '"Upcoming Bills" on your dashboard — so repayments don\'t sneak '
        'up on you.',
  ),
  OnboardingStep(
    title: '6. Automate Recurring Money',
    icon: Icons.repeat,
    body: 'Set up a rule for money that moves on a schedule — daily, '
        'weekly or monthly — and EazyVault creates those transactions for '
        'you, even generating any you missed the next time you open the app.',
    example: 'Salary → Monthly   ·   Rent → Monthly',
  ),
  OnboardingStep(
    title: '7. Keep Track of Money Owed',
    icon: Icons.handshake_outlined,
    body: 'Use Lend and Borrow to record money you\'ve given to or taken '
        'from someone, with an amount and optional due date. Record a '
        'repayment any time to update how much is left.',
  ),
  OnboardingStep(
    title: '8. See Your Financial Progress',
    icon: Icons.insights_outlined,
    body: 'Your dashboard brings account balances, income, expenses, '
        'spending trends, net worth and budget status together — so you '
        'can see where your money is going and how your financial '
        'position changes over time.',
  ),
  OnboardingStep(
    title: 'More Tools',
    icon: Icons.apps_outlined,
    body: 'A few more things worth knowing:\n\n'
        '• Receipts & Photos — attach a receipt to any transaction so the '
        'record stays with it.\n\n'
        '• CSV Bank Import — coming soon: import transactions from a bank '
        'statement instead of entering them by hand.\n\n'
        '• Notifications — turn on browser alerts for bills and budgets '
        'in Settings; the in-app bell always shows them too.\n\n'
        '• Settings — manage your profile and preferences any time.\n\n'
        '• Need help later? Open the User Manual any time from the '
        'dashboard or Settings.',
  ),
];
