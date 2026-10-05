import 'package:flutter/material.dart';
import 'package:budget_manager/l10n/app_localizations.dart';

import '../api/api.dart';
import '../app/app_scope.dart';
import '../models/models.dart';
import 'widgets/error_views.dart';

/// Add, rename, reorder and delete expense categories. Deleting a category
/// also deletes every expense in it, in all months, so it asks first.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category>? _categories;
  ApiException? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AppScope.of(context).api;
    try {
      final categories = await api.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Reloads the list and the month, whose categories come with it.
  Future<void> _afterChange() async {
    await _load();
    if (mounted) await AppScope.of(context).months.refresh();
  }

  void _showError(ApiException e) {
    final l10n = AppLocalizations.of(context)!;
    final message = e.message.toLowerCase().contains('unique') ? l10n.categoryExists : describeApiError(e, l10n);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit({Category? category}) async {
    final l10n = AppLocalizations.of(context)!;
    final api = AppScope.of(context).api;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: category == null ? l10n.newCategory : l10n.editCategory,
        initialName: category?.name ?? '',
      ),
    );
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    try {
      if (category == null) {
        await api.createCategory(name);
      } else {
        await api.updateCategory(id: category.id, name: name);
      }
      await _afterChange();
    } on ApiException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Category category) async {
    final l10n = AppLocalizations.of(context)!;
    final api = AppScope.of(context).api;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(l10n.deleteCategory),
        content: Text('${category.name}\n\n${l10n.deleteCategoryWarning}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: Text(l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await api.deleteCategory(category.id);
      await _afterChange();
    } on ApiException catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// [newIndex] is already adjusted for the removed item (onReorderItem).
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final api = AppScope.of(context).api;
    final categories = [...?_categories];
    final moved = categories.removeAt(oldIndex);
    categories.insert(newIndex, moved);
    setState(() => _categories = categories);
    try {
      await api.reorderCategories(categories);
      if (mounted) await AppScope.of(context).months.refresh();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final categories = _categories;

    final Widget body;
    if (categories == null) {
      final error = _error;
      body = error == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [ErrorBanner(error: error, onRetry: _load)]);
    } else if (categories.isEmpty) {
      body = Center(
        child: Text(l10n.noCategoriesYet, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
    } else {
      body = Column(
        children: [
          if (_error != null) ErrorBanner(error: _error!, onRetry: _load),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.reorderHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: categories.length,
              onReorderItem: _busy ? (_, __) {} : _reorder,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  key: ValueKey(category.id),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const Icon(Icons.drag_handle_rounded),
                  ),
                  title: Text(category.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    tooltip: l10n.deleteCategory,
                    onPressed: _busy ? null : () => _delete(category),
                  ),
                  onTap: _busy ? null : () => _edit(category: category),
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manageCategories),
        bottom: _busy
            ? const PreferredSize(preferredSize: Size.fromHeight(2), child: LinearProgressIndicator(minHeight: 2))
            : null,
      ),
      body: body,
      floatingActionButton: FloatingActionButton(
        onPressed: _busy ? null : () => _edit(),
        tooltip: l10n.newCategory,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.nameRequired);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(labelText: l10n.categoryName, errorText: _error),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
