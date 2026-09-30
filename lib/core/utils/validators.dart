import '../constants/app_constants.dart';

class Validators {
  const Validators._();

  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < ValidationConstants.minPasswordLength) {
      return 'Password must be at least ${ValidationConstants.minPasswordLength} characters';
    }

    if (value.length > ValidationConstants.maxPasswordLength) {
      return 'Password must not exceed ${ValidationConstants.maxPasswordLength} characters';
    }

    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'This field'} is required';
    }
    return null;
  }

  static String? name(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Name'} is required';
    }

    if (value.trim().length < ValidationConstants.minNameLength) {
      return '${fieldName ?? 'Name'} must be at least ${ValidationConstants.minNameLength} characters';
    }

    if (value.trim().length > ValidationConstants.maxNameLength) {
      return '${fieldName ?? 'Name'} must not exceed ${ValidationConstants.maxNameLength} characters';
    }

    return null;
  }

  static String? amount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      return 'Please enter a valid amount';
    }

    if (amount < ValidationConstants.minAmount) {
      return 'Amount must be at least ${ValidationConstants.minAmount}';
    }

    if (amount > ValidationConstants.maxAmount) {
      return 'Amount must not exceed ${ValidationConstants.maxAmount}';
    }

    return null;
  }

  static String? positiveAmount(String? value) {
    final amountError = amount(value);
    if (amountError != null) {
      return amountError;
    }

    final parsedAmount = double.parse(value!.trim());
    if (parsedAmount <= 0) {
      return 'Amount must be greater than zero';
    }

    return null;
  }

  static String? description(String? value, {bool required = false}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Description is required';
    }

    if (value != null && value.trim().length > ValidationConstants.maxDescriptionLength) {
      return 'Description must not exceed ${ValidationConstants.maxDescriptionLength} characters';
    }

    return null;
  }

  static String? vendorName(String? value, {bool required = false}) {
    if (required && (value == null || value.trim().isEmpty)) {
      return 'Vendor name is required';
    }

    if (value != null && value.trim().length > ValidationConstants.maxVendorNameLength) {
      return 'Vendor name must not exceed ${ValidationConstants.maxVendorNameLength} characters';
    }

    return null;
  }

  /// Optional phone number or email. Empty is valid.
  static String? optionalContact(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.contains('@')) return email(text);
    final digits = text.replaceAll(RegExp(r'[\s\-()+]'), '');
    if (!RegExp(r'^\d{7,15}$').hasMatch(digits)) {
      return 'Please enter a valid phone number or email';
    }
    return null;
  }
}
