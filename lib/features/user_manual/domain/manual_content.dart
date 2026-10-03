import 'package:flutter/material.dart';

/// One topic within a [ManualSection] — a heading plus its body text.
/// `body` may contain literal `\n` line breaks for short lists.
class ManualEntry {
  const ManualEntry({required this.heading, required this.body});

  final String heading;
  final String body;
}

class ManualSection {
  const ManualSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.entries,
  });

  final String id;
  final String title;
  final IconData icon;
  final List<ManualEntry> entries;
}

/// The User Manual's content, grouped the same way the navigation shows it.
///
/// This describes EazyVault as it actually behaves today, not as any
/// earlier spec described it — in particular: budgets are a category plus
/// a fixed monthly limit (there's no custom budget period or editable
/// threshold), "Bills" is the dashboard's view of loan due dates rather
/// than a separate bill-tracking feature, and recurring rules only support
/// Daily/Weekly/Monthly. Only features with a working UI entry point are
/// documented here — CSV import, for example, has real code behind it but
/// no reachable screen yet, so it's deliberately left out rather than
/// described as available or even "coming soon."
const List<ManualSection> manualSections = [
  ManualSection(
    id: 'getting-started',
    title: 'Getting Started',
    icon: Icons.flag_outlined,
    entries: [
      ManualEntry(
        heading: 'What is EazyVault?',
        body: 'EazyVault is a personal finance manager. You track your own '
            'accounts, income, expenses, transfers, budgets and money '
            'lent or borrowed in one place, and the dashboard summarizes '
            'all of it.',
      ),
      ManualEntry(
        heading: 'First-time setup',
        body: 'After signing up, EazyVault seeds a starter set of income '
            'and expense categories for you automatically. From there, '
            "add your first account and you're ready to record "
            'transactions.',
      ),
      ManualEntry(
        heading: 'Add your first account',
        body: "Open Accounts (from the dashboard's Quick Actions or the "
            'Accounts tab) and add an account with a name, type and '
            'opening balance — the balance it had at the moment you '
            'started tracking it in EazyVault.',
      ),
      ManualEntry(
        heading: 'Understanding the dashboard',
        body: 'The dashboard is the hub of the app. Quick Actions let you '
            'add income/expenses, transfer money, lend/borrow, and reach '
            'every other feature. Below that, cards show your total '
            "balance, this month's income and expenses, account "
            'breakdown, spending trends, net worth, budgets, loans and '
            'upcoming bills.',
      ),
    ],
  ),
  ManualSection(
    id: 'accounts',
    title: 'Accounts',
    icon: Icons.account_balance_wallet_outlined,
    entries: [
      ManualEntry(
        heading: 'Adding an account',
        body: 'Give it a name, choose a type (Cash, Savings, Current, UPI '
            'or Credit Card), pick a color/icon, and enter its opening '
            'balance.',
      ),
      ManualEntry(
        heading: 'Editing an account',
        body: 'You can rename an account, change its type, color, icon, '
            "description or active status at any time. Its opening "
            "balance can't be changed after the account is created — "
            "that field is locked on the edit form — since the current "
            'balance already reflects it.',
      ),
      ManualEntry(
        heading: 'Opening balance vs. current balance',
        body: 'Opening balance is what the account held the moment you '
            'added it to EazyVault. Current balance is the opening '
            'balance plus the effect of every transaction recorded since '
            '— EazyVault keeps it updated automatically so the dashboard '
            "doesn't have to recalculate it every time.",
      ),
      ManualEntry(
        heading: 'If a balance looks wrong',
        body: 'Use the 🔄 "Sync balances" action — available from the '
            "dashboard's Total Balance card and from the Accounts page "
            "— to recompute every account's current balance from its "
            'opening balance and full transaction history.',
      ),
      ManualEntry(
        heading: 'Transfers between accounts',
        body: 'A transfer moves money from one of your accounts to '
            'another in a single step — it debits the source and credits '
            'the destination together, so your total balance across '
            "accounts doesn't change.",
      ),
      ManualEntry(
        heading: 'Account history',
        body: 'Open an account to see every transaction that has '
            'affected it, including transfers into it from another '
            'account.',
      ),
    ],
  ),
  ManualSection(
    id: 'transactions',
    title: 'Transactions',
    icon: Icons.receipt_long_outlined,
    entries: [
      ManualEntry(
        heading: 'Adding income or an expense',
        body: 'Choose an account, category, amount, date and an optional '
            'note. Income also has an "Income For" month, separate from '
            'the credited date, used purely for monthly income reports — '
            'so money credited at the end of one month can still be '
            "reported as the next month's income if that's how it's "
            'meant to count.',
      ),
      ManualEntry(
        heading: 'Adding a transfer',
        body: 'Pick a source account, a destination account, and an '
            "amount. The source account's balance can't go negative.",
      ),
      ManualEntry(
        heading: 'Editing a transaction',
        body: 'Income and expenses can be edited freely. Transfers and '
            "loan-related transactions can't be edited once created — "
            'delete and re-create them instead.',
      ),
      ManualEntry(
        heading: 'Deleting a transaction',
        body: 'Deleting reverses its effect on the account balance(s) it '
            'touched. Transactions are never permanently erased — '
            "they're marked deleted and excluded from lists and totals.",
      ),
      ManualEntry(
        heading: 'Categories, notes, dates and attachments',
        body: 'Every transaction has a category (except transfers and '
            "loans, which don't use one), an optional note, the date "
            'money actually moved, and you can attach a receipt or photo.',
      ),
    ],
  ),
  ManualSection(
    id: 'categories',
    title: 'Categories',
    icon: Icons.category_outlined,
    entries: [
      ManualEntry(
        heading: 'Creating a category',
        body: "Give it a name, choose whether it's an Income or Expense "
            'category, and pick a color/icon.',
      ),
      ManualEntry(
        heading: 'Editing and deleting',
        body: 'You can rename or restyle a category at any time. '
            'Categories are typed as income or expense and that type '
            "can't be changed after creation.",
      ),
      ManualEntry(
        heading: 'Default categories',
        body: 'EazyVault seeds a set of common categories automatically '
            "the first time you have none — you're free to edit or add "
            'to them.',
      ),
      ManualEntry(
        heading: "Why transfers and loans don't show a category",
        body: 'Transfers and money lent/borrowed are tracked separately '
            'from your category list by design — they represent money '
            'moving between your own accounts or with another person, '
            'not spending or income.',
      ),
    ],
  ),
  ManualSection(
    id: 'budgets',
    title: 'Budgets',
    icon: Icons.savings_outlined,
    entries: [
      ManualEntry(
        heading: 'Creating a budget',
        body: "From the dashboard's Budgets quick action, choose an "
            'expense category and set a monthly limit. Only categories '
            "that don't already have a budget are offered, so each "
            'category has at most one.',
      ),
      ManualEntry(
        heading: 'Budget period',
        body: 'Every budget tracks spending for the current calendar '
            "month — there's no separate weekly/custom period option.",
      ),
      ManualEntry(
        heading: 'Understanding budget usage',
        body: "EazyVault totals this month's expenses in that category "
            'and compares it to your limit on the fly, showing amount '
            'spent, remaining, and percentage used.',
      ),
      ManualEntry(
        heading: 'Budget thresholds and notifications',
        body: 'EazyVault can alert you when a budget crosses 80%, 90% or '
            '100% of its limit, once per threshold per month. See '
            'Notifications for how alerts are delivered.',
      ),
      ManualEntry(
        heading: "Changing a budget's category",
        body: "A budget's category can't be changed after it's "
            'created — delete it and create a new one instead.',
      ),
    ],
  ),
  ManualSection(
    id: 'bills',
    title: 'Bills',
    icon: Icons.event_outlined,
    entries: [
      ManualEntry(
        heading: 'How EazyVault tracks bills',
        body: "EazyVault doesn't have a separate bill-tracking feature. "
            '"Upcoming Bills" on your dashboard is a live view of money '
            "you've lent or borrowed (see Money Lent / Borrowed) that "
            'has a due date coming up in the next 30 days, or is already '
            'overdue.',
      ),
      ManualEntry(
        heading: 'Paying a bill',
        body: 'There\'s no separate "mark as paid" action — recording a '
            'repayment on the underlying loan is what clears it from '
            'Upcoming Bills.',
      ),
      ManualEntry(
        heading: 'Recurring expenses like rent or subscriptions',
        body: "For a regular payment that isn't money lent or borrowed "
            '— rent, a subscription, an EMI — set it up as a Recurring '
            "Transaction instead (see the next section); it isn't "
            'listed under Upcoming Bills.',
      ),
    ],
  ),
  ManualSection(
    id: 'recurring',
    title: 'Recurring Transactions',
    icon: Icons.repeat,
    entries: [
      ManualEntry(
        heading: 'Creating a recurring rule',
        body: "From the dashboard's Recurring quick action, set the "
            'transaction type (income or expense), account, category, '
            'amount, a start date and how often it repeats.',
      ),
      ManualEntry(
        heading: 'Supported frequencies',
        body: "Daily, Weekly or Monthly. There isn't a yearly or "
            'custom-interval option.',
      ),
      ManualEntry(
        heading: 'Start date and end date',
        body: 'A rule starts generating transactions from its start '
            'date. An end date is optional — leave it blank for a rule '
            'that continues indefinitely.',
      ),
      ManualEntry(
        heading: 'Catch-up behavior',
        body: 'EazyVault checks for anything a rule owes once each time '
            'you open the app, and generates every occurrence due since '
            'the last time it ran — including several at once if the '
            "app hasn't been opened in a while. It isn't a background "
            'job; it only runs while the app is open.',
      ),
      ManualEntry(
        heading: 'Editing or removing a rule',
        body: 'Unlike transfers and loans, a recurring rule can be '
            'edited at any time — change the amount, schedule or any '
            'other field. Removing a rule stops future transactions but '
            "doesn't undo ones already generated.",
      ),
    ],
  ),
  ManualSection(
    id: 'loans',
    title: 'Money Lent / Borrowed',
    icon: Icons.handshake_outlined,
    entries: [
      ManualEntry(
        heading: 'Recording money you lend or borrow',
        body: "Use the dashboard's Lend or Borrow quick action. Enter "
            "the account, the other person's name (and optionally their "
            'contact info), the amount, and an optional due date and '
            'interest rate.',
      ),
      ManualEntry(
        heading: 'Splitting into installments',
        body: 'Turn on installments to split the amount into several '
            'due dates between now and the due date, instead of one '
            'lump sum.',
      ),
      ManualEntry(
        heading: 'Status: pending, partial, completed, overdue',
        body: 'A loan starts "pending". Partial repayments mark it '
            '"partial"; repaying in full marks it "completed". '
            '"Overdue" isn\'t a status EazyVault stores — it\'s shown '
            'automatically for anything not yet completed whose due '
            'date has passed.',
      ),
      ManualEntry(
        heading: 'Recording a repayment',
        body: 'Open the loan from the Loans summary card on your '
            'dashboard and record a repayment. The amount field starts '
            "pre-filled with what's still owed, and EazyVault won't "
            'let you record more than that remaining amount.',
      ),
      ManualEntry(
        heading: 'Viewing outstanding amounts',
        body: "The dashboard's Loans summary card shows what's owed to "
            "you and what you owe. There isn't a separate dedicated "
            'Loans page — everything is reached from there.',
      ),
    ],
  ),
  ManualSection(
    id: 'reports',
    title: 'Reports & Insights',
    icon: Icons.summarize_outlined,
    entries: [
      ManualEntry(
        heading: 'Report types',
        body: 'Open Reports from the dashboard for eight report types: '
            'Monthly, Transaction Statement, Account Statement, Income, '
            'Expense, Category, Loans & Debts, and Annual. Each can be '
            'exported as PDF or Excel.',
      ),
      ManualEntry(
        heading: 'Date filters',
        body: 'Most reports let you choose a month, a year, or a custom '
            'date range, and some support filtering by account or '
            'category.',
      ),
      ManualEntry(
        heading: 'Net worth / balance history',
        body: "The dashboard's Net Worth chart (not one of the "
            'exportable reports) plots your combined account balances '
            'over time — This Week, This Month, This Quarter, This Year, '
            'or a custom range you choose.',
      ),
      ManualEntry(
        heading: 'What the numbers mean',
        body: 'Income/Expense reports total actual transactions in that '
            'period; Account Statement shows a running balance the way a '
            'bank statement would; Loans & Debts reflects amounts owed '
            'right now rather than a historical period.',
      ),
    ],
  ),
  ManualSection(
    id: 'attachments',
    title: 'Attachments',
    icon: Icons.attach_file,
    entries: [
      ManualEntry(
        heading: 'Adding a receipt or photo',
        body: 'Open a transaction\'s detail view and choose "Add '
            'Attachment", then pick a file.',
      ),
      ManualEntry(
        heading: 'Supported files',
        body: 'Images (JPG, PNG, GIF, WebP) and PDF files, up to 5 MB '
            'each.',
      ),
      ManualEntry(
        heading: 'Viewing and removing',
        body: 'An attached file opens in a new browser tab from "View '
            'Attachment", and can be removed from the transaction at '
            'any time.',
      ),
      ManualEntry(
        heading: 'If an upload fails',
        body: 'EazyVault shows a specific message — for example if the '
            "file couldn't be read, or the upload itself failed — so "
            'you can try again.',
      ),
    ],
  ),
  ManualSection(
    id: 'notifications',
    title: 'Notifications',
    icon: Icons.notifications_outlined,
    entries: [
      ManualEntry(
        heading: 'What triggers an alert',
        body: 'Two kinds: a budget crossing 80%/90%/100% of its limit, '
            'and a loan due date approaching (3 days out, the day '
            "before, the day of, and then daily once it's overdue).",
      ),
      ManualEntry(
        heading: 'How alerts are delivered',
        body: 'The in-app bell icon always shows current alerts. Real '
            'browser push notifications are an additional layer on top, '
            'and only work on the web version with notification '
            'permission granted.',
      ),
      ManualEntry(
        heading: 'Enabling or disabling browser alerts',
        body: 'Turn "Budget & bill alerts" on or off from Profile & '
            'Settings. Turning it on will prompt your browser for '
            "notification permission if you haven't answered that yet.",
      ),
      ManualEntry(
        heading: 'Platform limitations',
        body: 'If your browser blocks or you deny notification '
            "permission, EazyVault can't show browser pop-ups — but the "
            "in-app bell keeps working regardless, since it doesn't "
            'depend on that permission.',
      ),
    ],
  ),
  ManualSection(
    id: 'settings',
    title: 'Profile & Settings',
    icon: Icons.settings_outlined,
    entries: [
      ManualEntry(
        heading: 'Updating your profile',
        body: 'Change your display name from Profile & Settings, opened '
            'from the person icon on your dashboard.',
      ),
      ManualEntry(
        heading: 'Email and account information',
        body: 'Your email and the date you joined are shown on the same '
            "page; your email itself isn't editable there.",
      ),
      ManualEntry(
        heading: 'Notification preferences',
        body: 'The "Budget & bill alerts" toggle lives on this page — '
            'see Notifications.',
      ),
      ManualEntry(
        heading: 'About Us and the User Manual',
        body: 'Both are reachable from Profile & Settings and from the '
            "dashboard's Quick Actions.",
      ),
    ],
  ),
  ManualSection(
    id: 'security',
    title: 'Security & Privacy',
    icon: Icons.shield_outlined,
    entries: [
      ManualEntry(
        heading: 'Protect your credentials',
        body: 'Use a strong, unique password, and never share your '
            'login details with anyone.',
      ),
      ManualEntry(
        heading: 'Use trusted devices',
        body: 'Sign in from devices and browsers you trust, and sign '
            "out when you're done on a shared or public computer.",
      ),
      ManualEntry(
        heading: 'Review your activity',
        body: 'Periodically check your accounts and recent transactions '
            "for anything that doesn't look right.",
      ),
      ManualEntry(
        heading: 'Handle your financial data carefully',
        body: 'EazyVault stores your financial records for your own '
            'use — treat exported reports and statements the same way '
            "you'd treat a bank statement.",
      ),
    ],
  ),
  ManualSection(
    id: 'faq',
    title: 'FAQ',
    icon: Icons.help_outline,
    entries: [
      ManualEntry(
        heading: 'Why is my account balance different from what I expect?',
        body: 'Current balance is your opening balance plus every '
            'transaction recorded since. If it looks off — often after '
            'editing an account or a transfer — use 🔄 Sync balances '
            "(Accounts page or the dashboard's Total Balance card) to "
            'recompute it from scratch.',
      ),
      ManualEntry(
        heading: "Why was a transaction created that I didn't add?",
        body: "It's likely a recurring rule catching up — EazyVault "
            'generates everything a rule owes since it last ran, once '
            'each time you open the app. See Recurring Transactions.',
      ),
      ManualEntry(
        heading: "Why didn't I get a notification?",
        body: 'Browser notifications need permission, and only work on '
            'the web version. Check the toggle in Profile & Settings, '
            "and your browser's notification permission for the site — "
            'the in-app bell shows the same alerts either way.',
      ),
      ManualEntry(
        heading: 'Can I attach a receipt to a transaction?',
        body: 'Yes — see Attachments.',
      ),
      ManualEntry(
        heading: 'How do I track money I lent someone?',
        body: 'Use the Lend quick action on your dashboard — see Money '
            'Lent / Borrowed.',
      ),
    ],
  ),
];
