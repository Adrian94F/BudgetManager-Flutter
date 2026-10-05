import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import '../tools/formatters.dart';
import 'widgets/error_views.dart';

/// Settings of the budget itself, kept on the server so the website and
/// both apps agree: the currency.
class BudgetSettingsScreen extends StatelessWidget {
  const BudgetSettingsScreen({super.key});

  void _pickCurrency(BuildContext context, String current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _CurrencySheet(current: current),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final currency = CurrencyScope.of(context);
    final symbol = Formatters.currencySymbol(currency, locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.budgetSettings)),
      body: ListView(
        padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.paddingOf(context).bottom),
        children: [
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(l10n.currency),
            subtitle: Text(l10n.currencyHint),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  symbol == currency ? currency : '$currency · $symbol',
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _pickCurrency(context, currency),
          ),
        ],
      ),
    );
  }
}

/// The server's currency list; a tap saves the choice and closes the sheet.
class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({required this.current});

  final String current;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  late Future<CurrencySettings> _future;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _future = AppScope.of(context).api.fetchCurrency();
  }

  void _reload() => setState(() => _future = AppScope.of(context).api.fetchCurrency());

  Future<void> _select(String code) async {
    final services = AppScope.of(context);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = code);
    try {
      await services.months.setCurrency(code);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.currencyUpdated)));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = null);
      messenger.showSnackBar(SnackBar(content: Text(describeApiError(e, l10n))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: FutureBuilder<CurrencySettings>(
          future: _future,
          builder: (context, snapshot) {
            final error = snapshot.error;
            if (error != null) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error is ApiException ? describeApiError(error, l10n) : '$error', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.tonal(onPressed: _reload, child: Text(l10n.retry)),
                  ],
                ),
              );
            }
            final choices = snapshot.data?.choices;
            if (choices == null) {
              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
            }
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(l10n.chooseCurrency, style: theme.textTheme.titleMedium),
                ),
                for (final choice in choices)
                  ListTile(
                    leading: SizedBox(
                      width: 40,
                      child: Text(
                        Formatters.currencySymbol(choice.code, locale),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    title: Text(choice.name),
                    subtitle: Text(choice.code),
                    trailing: _saving == choice.code
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : choice.code == widget.current
                            ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                            : null,
                    onTap: _saving == null ? () => _select(choice.code) : null,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
