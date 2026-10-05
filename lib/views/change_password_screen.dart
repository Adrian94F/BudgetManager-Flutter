import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import 'widgets/error_views.dart';

/// Changes the account password through api/change-password/, showing the
/// server's validation messages under the fields they concern.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _oldController.text.isNotEmpty && _newController.text.isNotEmpty && _confirmController.text.isNotEmpty;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final api = AppScope.of(context).api;
    final messenger = ScaffoldMessenger.of(context);
    if (_newController.text != _confirmController.text) {
      setState(() {
        _error = null;
        _fieldErrors = {'new_password2': l10n.passwordsDoNotMatch};
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await api.changePassword(
        oldPassword: _oldController.text,
        newPassword: _newController.text,
        newPasswordConfirmation: _confirmController.text,
      );
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.passwordChanged)));
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? (e.isNetwork ? l10n.errorServerUnavailable : e.message) : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12.0));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.changePassword),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: AutofillGroup(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.paddingOf(context).bottom),
          children: [
            if (_error != null) ...[
              FormErrorBox(message: _error!),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _oldController,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.oldPassword,
                prefixIcon: const Icon(Icons.lock_outline),
                border: border,
                errorText: _fieldErrors['old_password'],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _newController,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.newPassword,
                prefixIcon: const Icon(Icons.key_outlined),
                border: border,
                errorText: _fieldErrors['new_password1'],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              enabled: !_busy,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _isValid && !_busy ? _submit() : null,
              decoration: InputDecoration(
                labelText: l10n.confirmNewPassword,
                prefixIcon: const Icon(Icons.key_outlined),
                border: border,
                errorText: _fieldErrors['new_password2'],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.passwordRules,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isValid && !_busy ? _submit : null,
              icon: const Icon(Icons.lock_reset_rounded),
              label: Text(l10n.changePassword),
            ),
          ],
        ),
      ),
    );
  }
}
