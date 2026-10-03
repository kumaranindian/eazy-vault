import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/breakpoints.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/date_time_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../notifications/domain/services/web_notifier.dart';
import '../../../notifications/presentation/providers/notification_settings_provider.dart';
import '../../data/models/user_model.dart';
import '../providers/auth_notifier.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isTogglingNotifications = false;
  String? _prefilledForUserId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _prefillIfNeeded(UserModel user) {
    if (_prefilledForUserId == user.id) return;
    _prefilledForUserId = user.id;
    _nameController.text = user.displayName ?? '';
  }

  Future<void> _handleSave(UserModel user) async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    setState(() => _isLoading = true);

    final failure = await ref
        .read(authNotifierProvider.notifier)
        .updateDisplayName(user.id, newName);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (failure == null) {
      context.showSuccessSnackBar('Profile updated successfully');
    } else {
      context.showErrorSnackBar(failure.message);
    }
  }

  Future<void> _handleToggleNotifications(bool value) async {
    setState(() => _isTogglingNotifications = true);
    await ref.read(notificationSettingsNotifierProvider.notifier).setEnabled(value);
    if (!mounted) return;
    setState(() => _isTogglingNotifications = false);

    if (!value) {
      context.showInfoSnackBar('Notification settings updated');
      return;
    }

    if (WebNotifier.permission == 'granted') {
      context.showSuccessSnackBar('Notification settings updated');
    } else {
      context.showErrorSnackBar(
        'Notifications are disabled. Enable notification permission in your browser settings.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final notificationsEnabledAsync = ref.watch(notificationSettingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: authState.when(
        initial: () => const LoadingIndicator(),
        loading: () => const LoadingIndicator(),
        unauthenticated: () => const SizedBox.shrink(),
        error: (failure) => Center(
          child: Padding(
            padding: AppSpacing.paddingMD,
            child: Text(failure.message),
          ),
        ),
        authenticated: (user) {
          _prefillIfNeeded(user);
          return ResponsiveContent(
            maxWidth: Breakpoints.formMaxWidth,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.paddingMD,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: context.colorScheme.primaryContainer,
                      child: Text(
                        (user.displayName?.isNotEmpty == true
                                ? user.displayName!.substring(0, 1)
                                : user.email.substring(0, 1))
                            .toUpperCase(),
                        style: context.textTheme.headlineMedium?.copyWith(
                          color: context.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.gapXL,
                  AppTextField(
                    controller: _nameController,
                    label: 'Display Name',
                    hint: 'Your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    validator: (value) => Validators.name(value, fieldName: 'Display name'),
                    enabled: !_isLoading,
                    textCapitalization: TextCapitalization.words,
                  ),
                  AppSpacing.gapMD,
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    trailing: Text(user.email),
                  ),
                  AppSpacing.gapMD,
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
                    title: const Text('Member Since'),
                    trailing: Text(user.createdAt.toFormattedDate()),
                  ),
                  AppSpacing.gapXL,
                  const Divider(),
                  AppSpacing.gapMD,
                  Text(
                    'Notifications',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Budget & bill alerts'),
                    subtitle: Text(
                      !WebNotifier.isSupported
                          ? 'Browser notifications aren\'t supported on this device. '
                              'The in-app bell will still show alerts.'
                          : WebNotifier.permission == 'denied'
                              ? 'Notifications are disabled. Enable notification '
                                  'permission in your browser settings.'
                              : 'Get notified when a budget is near its limit or a '
                                  'loan payment is coming due.',
                    ),
                    value: notificationsEnabledAsync.valueOrNull ?? false,
                    onChanged: _isTogglingNotifications
                        ? null
                        : (value) => _handleToggleNotifications(value),
                  ),
                  AppSpacing.gapXL,
                  const Divider(),
                  AppSpacing.gapMD,
                  Text(
                    'Help',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined),
                    title: const Text('Getting Started'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteConstants.gettingStarted),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('User Manual'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteConstants.userManual),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text('About Us'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(RouteConstants.about),
                  ),
                  AppSpacing.gapXL,
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleSave(user),
                    child: _isLoading
                        ? const ButtonProgress(label: 'Saving...')
                        : const Text('Save Changes'),
                  ),
                  AppSpacing.gapXL,
                  Center(
                    child: Text(
                      'EazyVault v${AppConfig.appVersion}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
