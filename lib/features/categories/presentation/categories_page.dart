import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/entities/event_category.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'color_palette.dart';

class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final repository = ref.read(categoryRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.categories)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l10n.newCategory),
        onPressed: () async {
          final result = await _editCategory(context, null);
          if (result != null) {
            await repository.create(name: result.name, color: result.color);
          }
        },
      ),
      body: ListView(
        children: [
          for (final c in categories)
            ListTile(
              leading: CircleAvatar(backgroundColor: Color(c.color)),
              title: Text(c.name),
              onTap: () async {
                final result = await _editCategory(context, c);
                if (result != null) {
                  await repository.update(
                    EventCategory(
                      id: c.id,
                      name: result.name,
                      color: result.color,
                      sortOrder: c.sortOrder,
                    ),
                  );
                }
              },
              trailing: IconButton(
                tooltip: l10n.delete,
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l10n.deleteCategoryTitle(c.name)),
                      content: Text(l10n.deleteCategoryBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.delete),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await repository.delete(c.id);
                },
              ),
            ),
        ],
      ),
    );
  }
}

Future<({String name, int color})?> _editCategory(
  BuildContext context,
  EventCategory? category,
) => showDialog(
  context: context,
  builder: (context) => _CategoryDialog(category: category),
);

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.category});

  final EventCategory? category;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final _name = TextEditingController(text: widget.category?.name);
  late int _color = widget.category?.color ?? paletteColors[5];
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).errorEmptyName);
      return;
    }
    Navigator.of(context).pop((name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(
        widget.category == null ? l10n.newCategory : l10n.editCategory,
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.fieldName,
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            ColorPalette(
              selected: _color,
              onSelected: (c) => setState(() => _color = c ?? _color),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
