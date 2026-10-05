import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../state/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverController = TextEditingController();
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    final services = AppScope.of(context);
    _usernameController.text = services.auth.savedUsername;
    _passwordController.text = services.auth.savedPassword;
    _rememberMe = services.auth.rememberMe;
    _serverController.text = services.settings.serverUrl ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final services = AppScope.of(context);
    if (services.auth.isBusy) return;
    FocusScope.of(context).unfocus();
    await services.settings.setServerUrl(_serverController.text);
    await services.auth.login(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );
  }

  /// Registration lives on the web app; it opens in a Custom Tab against the
  /// server typed in the form.
  Future<void> _openRegistration() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final base = ApiClient.normalizeBaseUrl(_serverController.text);
    final opened = await launchUrl(Uri.parse('$base/register'),
        mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.cannotOpenBrowser)));
    }
  }

  String? _errorText(AuthController auth, AppLocalizations l10n) {
    if (auth.sessionExpired) return l10n.sessionExpired;
    return switch (auth.failure) {
      null => null,
      LoginFailure.invalidCredentials => l10n.errorInvalidCredentials,
      LoginFailure.serverUnavailable => l10n.errorServerUnavailable,
      LoginFailure.other => auth.failureDetail ?? l10n.loginFailed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final auth = AppScope.of(context).auth;
    const fieldBorder = OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12.0)));

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ListenableBuilder(
              listenable: auth,
              builder: (context, _) {
                final error = _errorText(auth, l10n);
                return AutofillGroup(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          size: 56, color: colors.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Budget Manager',
                        style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: colors.primary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          prefixIcon: const Icon(Icons.person_outline),
                          border: fieldBorder,
                        ),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.username],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: fieldBorder,
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _serverController,
                        decoration: InputDecoration(
                          labelText: l10n.serverUrl,
                          prefixIcon: const Icon(Icons.dns_outlined),
                          border: fieldBorder,
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                        title: Text(l10n.rememberMe),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color: colors.error, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(error,
                                  style: textTheme.bodyMedium
                                      ?.copyWith(color: colors.error)),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: auth.isBusy ? null : _login,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0)),
                          ),
                          child: auth.isBusy
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 3))
                              : Text(l10n.login.toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.noAccountYet, style: textTheme.bodyMedium),
                          TextButton(
                              onPressed: _openRegistration,
                              child: Text(l10n.register)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
