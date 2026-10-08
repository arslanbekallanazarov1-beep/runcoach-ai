import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../widgets/app_surface_card.dart';
import '../widgets/heart_rate_zones_display.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.authService,
    required this.onUserUpdated,
    required this.languageCode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
    required this.onLogout,
    super.key,
  });

  final AuthUser user;
  final AuthService authService;
  final ValueChanged<AuthUser> onUserUpdated;
  final String languageCode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;
  final Future<void> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;
  bool _isSaving = false;
  bool _isLoadingZones = false;
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _maxHrController;
  late final TextEditingController _ageController;
  Map<String, Map<String, int>>? _zones;
  bool _zonesLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _maxHrController = TextEditingController(
      text: widget.user.maxHr?.toString() ?? '',
    );
    _ageController = TextEditingController(
      text: widget.user.age?.toString() ?? '',
    );
    unawaited(_loadZones(widget.user));
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.maxHr != widget.user.maxHr ||
        oldWidget.user.age != widget.user.age) {
      _maxHrController.text = widget.user.maxHr?.toString() ?? '';
      _ageController.text = widget.user.age?.toString() ?? '';
      unawaited(_loadZones(widget.user));
    }
  }

  @override
  void dispose() {
    _maxHrController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadZones(AuthUser user) async {
    if (user.maxHr == null) {
      setState(() {
        _zones = null;
        _zonesLoadFailed = false;
        _isLoadingZones = false;
      });
      return;
    }
    setState(() {
      _isLoadingZones = true;
      _zonesLoadFailed = false;
    });
    try {
      final zones = await widget.authService.fetchHeartRateZones();
      if (!mounted) return;
      setState(() {
        _zones = zones;
        _isLoadingZones = false;
      });
    } on AuthException {
      if (!mounted) return;
      setState(() {
        _zones = null;
        _zonesLoadFailed = true;
        _isLoadingZones = false;
      });
    }
  }

  String? _validateMaxHr(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final maxHr = int.tryParse(trimmed);
    if (maxHr == null || maxHr < 120 || maxHr > 240) {
      return AppStrings.of(context).invalidMaxHeartRate;
    }
    return null;
  }

  String? _validateAge(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    final age = int.tryParse(trimmed);
    if (age == null || age < 10 || age > 120) {
      return AppStrings.of(context).invalidAge;
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final maxHrText = _maxHrController.text.trim();
    final ageText = _ageController.text.trim();
    setState(() => _isSaving = true);
    try {
      final user = await widget.authService.updateProfile(
        maxHr: maxHrText.isEmpty ? null : int.parse(maxHrText),
        clearMaxHr: maxHrText.isEmpty && widget.user.maxHr != null,
        age: ageText.isEmpty ? null : int.parse(ageText),
        clearAge: ageText.isEmpty && widget.user.age != null,
      );
      if (!mounted) return;
      widget.onUserUpdated(user);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSaved)),
      );
    } on AuthException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).profileSaveFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.of(context).authLogoutFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ProfileHeader(
                    onLocaleChanged: widget.onLocaleChanged,
                    onThemeModeChanged: widget.onThemeModeChanged,
                  ),
                  const SizedBox(height: 24),
                  AppSurfaceCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.profile,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 16),
                          _UserInfoSection(user: widget.user),
                          const SizedBox(height: 20),
                          _HeartRateProfileSection(
                            formKey: _formKey,
                            maxHrController: _maxHrController,
                            ageController: _ageController,
                            validateMaxHr: _validateMaxHr,
                            validateAge: _validateAge,
                            isSaving: _isSaving,
                            isLoadingZones: _isLoadingZones,
                            zones: _zones,
                            zonesLoadFailed: _zonesLoadFailed,
                            maxHr: widget.user.maxHr,
                            age: widget.user.age,
                            onSave: _saveProfile,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isLoggingOut ? null : _logout,
                              icon: _isLoggingOut
                                  ? SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.logout_rounded),
                              label: Text(
                                strings.authLogout,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartRateProfileSection extends StatelessWidget {
  const _HeartRateProfileSection({
    required this.formKey,
    required this.maxHrController,
    required this.ageController,
    required this.validateMaxHr,
    required this.validateAge,
    required this.isSaving,
    required this.isLoadingZones,
    required this.zones,
    required this.zonesLoadFailed,
    required this.maxHr,
    required this.age,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController maxHrController;
  final TextEditingController ageController;
  final FormFieldValidator<String> validateMaxHr;
  final FormFieldValidator<String> validateAge;
  final bool isSaving;
  final bool isLoadingZones;
  final Map<String, Map<String, int>>? zones;
  final bool zonesLoadFailed;
  final int? maxHr;
  final int? age;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const ValueKey('profile-max-hr'),
            controller: maxHrController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.maximumHeartRate,
              suffixText: strings.bpm,
            ),
            validator: validateMaxHr,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('profile-age'),
            controller: ageController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: strings.age,
              suffixText: strings.years,
            ),
            validator: validateAge,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSave,
              child: isSaving
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(strings.savingProfile),
                      ],
                    )
                  : Text(strings.saveProfile),
            ),
          ),
          const SizedBox(height: 20),
          if (isLoadingZones)
            const Center(child: CircularProgressIndicator())
          else if (zonesLoadFailed)
            Text(
              strings.heartRateZonesLoadFailed,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            )
          else if (zones == null)
            Text(
              strings.setMaxHeartRateForZones,
              style: Theme.of(context).textTheme.bodyMedium,
            )
          else
            HeartRateZonesDisplay(
              zones: zones!,
              age: age,
              maxHr: maxHr,
            ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<bool> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context);
    final isDarkMode = colorScheme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Text(
            strings.trainingPlan,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        PopupMenuButton<Locale>(
          key: const ValueKey('profile-language-toggle'),
          tooltip: strings.language,
          onSelected: onLocaleChanged,
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: const Locale('en'),
              checked: locale.languageCode == 'en',
              child: const Text('English'),
            ),
            CheckedPopupMenuItem(
              value: const Locale('ru'),
              checked: locale.languageCode == 'ru',
              child: const Text('Русский'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              locale.languageCode.toUpperCase(),
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: isDarkMode ? strings.switchToLight : strings.switchToDark,
          onPressed: () => onThemeModeChanged(!isDarkMode),
          icon: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          ),
        ),
      ],
    );
  }
}

class _UserInfoSection extends StatelessWidget {
  const _UserInfoSection({
    required this.user,
  });

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 32,
                color: colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${user.firstName} ${user.lastName}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Divider(color: colorScheme.outlineVariant, thickness: 1),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _InfoCard(
                title: strings.kilometersOfProgress,
                value: '--',
                icon: Icons.directions_run_rounded,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _InfoCard(
                title: strings.calories,
                value: '--',
                icon: Icons.local_fire_department_rounded,
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
