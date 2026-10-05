import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../../api/api.dart';

/// User-facing text for an [ApiException].
String describeApiError(ApiException error, AppLocalizations l10n) {
  if (error.isNetwork) return l10n.errorServerUnavailable;
  if (error.isAuth) return l10n.sessionExpired;
  return '${l10n.errorLoadingData} (${error.message})';
}

/// Full-screen error shown when there is no data to fall back on.
class ErrorScreen extends StatelessWidget {
  const ErrorScreen(
      {super.key, required this.error, required this.onRetry, this.onLogout});

  final ApiException error;
  final VoidCallback onRetry;
  final VoidCallback? onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error.isNetwork
                      ? Icons.cloud_off_rounded
                      : Icons.error_outline_rounded,
                  size: 48,
                  color: colors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  describeApiError(error, l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.retry),
                ),
                if (onLogout != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onLogout, child: Text(l10n.logOut)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Validation or server error at the top of a form.
class FormErrorBox extends StatelessWidget {
  const FormErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12.0)),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}

/// Inline error shown above data that is still on screen.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error, required this.onRetry});

  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                describeApiError(error, l10n),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

/// Shown when the account has no month yet.
class NoMonthView extends StatelessWidget {
  const NoMonthView({super.key, this.message, required this.onCreate});

  final String? message;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        const SizedBox(height: 48),
        Icon(Icons.calendar_month_rounded, size: 64, color: colors.primary),
        const SizedBox(height: 16),
        Text(
          message ?? l10n.noMonths,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.newMonth),
          ),
        ),
      ],
    );
  }
}
