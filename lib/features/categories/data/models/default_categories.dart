import 'package:flutter/material.dart';

import '../../domain/enums/category_type.dart';

class DefaultCategory {
  const DefaultCategory({
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.description,
  });

  final String name;
  final CategoryType type;
  final int color;
  final String icon;
  final String? description;
}

class DefaultCategories {
  const DefaultCategories._();

  static const List<DefaultCategory> incomeCategories = [
    DefaultCategory(
      name: 'Salary',
      type: CategoryType.income,
      color: 0xFF4CAF50,
      icon: '💰',
      description: 'Monthly salary and wages',
    ),
    DefaultCategory(
      name: 'Business',
      type: CategoryType.income,
      color: 0xFF2196F3,
      icon: '💼',
      description: 'Business income and profits',
    ),
    DefaultCategory(
      name: 'Freelance',
      type: CategoryType.income,
      color: 0xFF9C27B0,
      icon: '💻',
      description: 'Freelance work and projects',
    ),
    DefaultCategory(
      name: 'Investment',
      type: CategoryType.income,
      color: 0xFFFF9800,
      icon: '📈',
      description: 'Returns from investments',
    ),
    DefaultCategory(
      name: 'Rental',
      type: CategoryType.income,
      color: 0xFF795548,
      icon: '🏠',
      description: 'Rental income from properties',
    ),
    DefaultCategory(
      name: 'Gift',
      type: CategoryType.income,
      color: 0xFFE91E63,
      icon: '🎁',
      description: 'Gifts and bonuses received',
    ),
    DefaultCategory(
      name: 'Other Income',
      type: CategoryType.income,
      color: 0xFF607D8B,
      icon: '💵',
      description: 'Other sources of income',
    ),
  ];

  static const List<DefaultCategory> expenseCategories = [
    DefaultCategory(
      name: 'Food & Dining',
      type: CategoryType.expense,
      color: 0xFFFF5722,
      icon: '🍔',
      description: 'Groceries, restaurants, and dining',
    ),
    DefaultCategory(
      name: 'Transportation',
      type: CategoryType.expense,
      color: 0xFF3F51B5,
      icon: '🚗',
      description: 'Fuel, public transport, and vehicle maintenance',
    ),
    DefaultCategory(
      name: 'Shopping',
      type: CategoryType.expense,
      color: 0xFFE91E63,
      icon: '🛒',
      description: 'Clothes, electronics, and other shopping',
    ),
    DefaultCategory(
      name: 'Entertainment',
      type: CategoryType.expense,
      color: 0xFF9C27B0,
      icon: '🎬',
      description: 'Movies, games, and entertainment',
    ),
    DefaultCategory(
      name: 'Healthcare',
      type: CategoryType.expense,
      color: 0xFFF44336,
      icon: '🏥',
      description: 'Medical expenses and insurance',
    ),
    DefaultCategory(
      name: 'Education',
      type: CategoryType.expense,
      color: 0xFF2196F3,
      icon: '🎓',
      description: 'Tuition, books, and courses',
    ),
    DefaultCategory(
      name: 'Bills & Utilities',
      type: CategoryType.expense,
      color: 0xFFFF9800,
      icon: '💡',
      description: 'Electricity, water, internet, and phone bills',
    ),
    DefaultCategory(
      name: 'Rent',
      type: CategoryType.expense,
      color: 0xFF795548,
      icon: '🏠',
      description: 'House rent and maintenance',
    ),
    DefaultCategory(
      name: 'Insurance',
      type: CategoryType.expense,
      color: 0xFF607D8B,
      icon: '🛡️',
      description: 'Life, health, and vehicle insurance',
    ),
    DefaultCategory(
      name: 'Travel',
      type: CategoryType.expense,
      color: 0xFF00BCD4,
      icon: '✈️',
      description: 'Vacation and travel expenses',
    ),
    DefaultCategory(
      name: 'Personal Care',
      type: CategoryType.expense,
      color: 0xFFE91E63,
      icon: '💄',
      description: 'Salon, spa, and personal grooming',
    ),
    DefaultCategory(
      name: 'Fitness',
      type: CategoryType.expense,
      color: 0xFF4CAF50,
      icon: '⚽',
      description: 'Gym, sports, and fitness activities',
    ),
    DefaultCategory(
      name: 'Gifts & Donations',
      type: CategoryType.expense,
      color: 0xFFFF4081,
      icon: '🎁',
      description: 'Gifts and charitable donations',
    ),
    DefaultCategory(
      name: 'Subscriptions',
      type: CategoryType.expense,
      color: 0xFF673AB7,
      icon: '📱',
      description: 'Netflix, Spotify, and other subscriptions',
    ),
    DefaultCategory(
      name: 'Other Expense',
      type: CategoryType.expense,
      color: 0xFF9E9E9E,
      icon: '💸',
      description: 'Miscellaneous expenses',
    ),
  ];

  static List<DefaultCategory> get allCategories => [
        ...incomeCategories,
        ...expenseCategories,
      ];
}
