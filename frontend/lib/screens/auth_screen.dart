import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../widgets/app_surface_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.service,
    required this.languageCode,
    required this.onLocaleChanged,
    required this.onAuthenticated,
    super.key,
  });

  final AuthService service;
  final String languageCode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<AuthUser> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isRegistering = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = _isRegistering
          ? await widget.service.register(
              email: _emailController.text,
              password: _passwordController.text,
              firstName: _firstNameController.text,
              lastName: _lastNameController.text,
            )
          : await widget.service.login(
              email: _emailController.text,
              password: _passwordController.text,
            );
      if (mounted) widget.onAuthenticated(user);
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error, AppStrings.of(context)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _messageFor(AuthException error, AppStrings strings) {
    if (error.statusCode == 401) return strings.authInvalidCredentials;
    if (error.statusCode == 409) return strings.authEmailAlreadyRegistered;
    if (error.statusCode == null) return strings.runCoachServerUnavailable;
    return strings.authRequestFailed;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      PopupMenuButton<Locale>(
                        tooltip: strings.language,
                        onSelected: widget.onLocaleChanged,
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: Locale('en'),
                            child: Text('English'),
                          ),
                          const PopupMenuItem(
                            value: Locale('ru'),
                            child: Text('Русский'),
                          ),
                        ],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(widget.languageCode.toUpperCase()),
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.directions_run_rounded, size: 52),
                  const SizedBox(height: 10),
                  Text(
                    strings.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(strings.tagline),
                  const SizedBox(height: 24),
                  AppSurfaceCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _isRegistering
                                ? strings.authSignUp
                                : strings.authLogin,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 18),
                          if (_isRegistering) ...[
                            TextFormField(
                              controller: _firstNameController,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.givenName],
                              decoration: InputDecoration(
                                labelText: strings.authFirstName,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? strings.authRequired
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _lastNameController,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.familyName],
                              decoration: InputDecoration(
                                labelText: strings.authLastName,
                              ),
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? strings.authRequired
                                      : null,
                            ),
                            const SizedBox(height: 12),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: strings.authEmail,
                            ),
                            validator: (value) =>
                                value == null ||
                                        !value.trim().contains('@') ||
                                        value.trim().length < 3
                                    ? strings.authInvalidEmail
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            autofillHints: [
                              _isRegistering
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: strings.authPassword,
                              helperText:
                                  _isRegistering ? strings.authPasswordHint : null,
                            ),
                            validator: (value) =>
                                (value?.length ?? 0) <
                                        (_isRegistering ? 8 : 1)
                                    ? strings.authPasswordInvalid
                                    : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: _isLoading ? null : _submit,
                            child: _isLoading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isRegistering
                                        ? strings.authCreateAccount
                                        : strings.authLogin,
                                  ),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                      _isRegistering = !_isRegistering;
                                      _error = null;
                                    }),
                            child: Text(
                              _isRegistering
                                  ? strings.authHaveAccount
                                  : strings.authNeedAccount,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
