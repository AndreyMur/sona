import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gradient_scaffold.dart';
import '../../../domain/models/category.dart';

/// Экран управления категориями и подкатегориями.
///
/// Позволяет добавить, переименовать и удалить категорию или подкатегорию —
/// ручная корректировка справочника поверх 16 категорий по умолчанию.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final Set<int> _expanded = {};

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return GradientScaffold(
      appBar: AppBar(title: const Text('Категории')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-category',
        onPressed: () => _addCategory(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Категория'),
      ),
      body: categories.when(
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  'Пока нет категорий',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                itemCount: list.length,
                itemBuilder: (context, index) => _CategoryCard(
                  category: list[index],
                  expanded: _expanded.contains(list[index].id),
                  onToggle: () => _toggle(list[index].id),
                  onRename: () => _renameCategory(list[index]),
                  onDelete: () => _deleteCategory(list[index]),
                  onAddSubcategory: () => _addSubcategory(list[index]),
                  onRenameSubcategory: (name) =>
                      _renameSubcategory(list[index], name),
                  onDeleteSubcategory: (name) =>
                      _deleteSubcategory(list[index], name),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(
            'Не удалось загрузить категории',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.add(id)) _expanded.remove(id);
    });
  }

  Future<void> _addCategory() async {
    final name = await _promptText(
      title: 'Новая категория',
      hint: 'Например: Хобби',
    );
    if (name == null || !mounted) return;
    await _guard(() async {
      final repository = ref.read(categoryRepositoryProvider);
      await repository.addCategory(name);
    }, failure: 'Категория не добавлена');
  }

  Future<void> _renameCategory(Category category) async {
    final name = await _promptText(
      title: 'Переименовать категорию',
      initial: category.name,
    );
    if (name == null || name == category.name || !mounted) return;
    await _guard(() async {
      await ref.read(categoryRepositoryProvider).renameCategory(
        category.id,
        name,
      );
    }, failure: 'Категория не переименована');
  }

  Future<void> _deleteCategory(Category category) async {
    final confirmed = await _confirmDelete(
      'Удалить категорию «${category.name}» вместе с подкатегориями?',
    );
    if (confirmed != true || !mounted) return;
    await _guard(() async {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    }, failure: 'Категория не удалена');
  }

  Future<void> _addSubcategory(Category category) async {
    final name = await _promptText(
      title: 'Новая подкатегория в «${category.name}»',
      hint: 'Например: Доставка',
    );
    if (name == null || !mounted) return;
    await _guard(() async {
      await ref
          .read(categoryRepositoryProvider)
          .addSubcategory(category.id, name);
    }, failure: 'Подкатегория не добавлена');
  }

  Future<void> _renameSubcategory(Category category, String oldName) async {
    final name = await _promptText(
      title: 'Переименовать подкатегорию',
      initial: oldName,
    );
    if (name == null || name == oldName || !mounted) return;
    await _guard(() async {
      await ref
          .read(categoryRepositoryProvider)
          .renameSubcategory(category.id, oldName, name);
    }, failure: 'Подкатегория не переименована');
  }

  Future<void> _deleteSubcategory(Category category, String name) async {
    final confirmed = await _confirmDelete(
      'Удалить подкатегорию «$name»?',
    );
    if (confirmed != true || !mounted) return;
    await _guard(() async {
      await ref
          .read(categoryRepositoryProvider)
          .deleteSubcategory(category.id, name);
    }, failure: 'Подкатегория не удалена');
  }

  Future<void> _guard(Future<void> Function() action,
      {required String failure}) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure)),
        );
      }
    }
  }

  Future<String?> _promptText({
    required String title,
    String? initial,
    String? hint,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

/// Карточка категории: заголовок с меню и раскрывающийся список подкатегорий.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.expanded,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
    required this.onAddSubcategory,
    required this.onRenameSubcategory,
    required this.onDeleteSubcategory,
  });

  final Category category;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onAddSubcategory;
  final ValueChanged<String> onRenameSubcategory;
  final ValueChanged<String> onDeleteSubcategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sona = context.sonaColors;
    final subtitle = category.subcategories.isEmpty
        ? 'Без подкатегорий'
        : '${category.subcategories.length} '
            'подкатегор${_plural(category.subcategories.length)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Card(
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: sona.accentSoft,
                  child: Text(
                    category.name.characters.first.toUpperCase(),
                    style: TextStyle(color: sona.onAccentSoft),
                  ),
                ),
                title: Text(category.name, style: theme.textTheme.titleMedium),
                subtitle: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Действия с категорией',
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onSelected: (value) {
                    if (value == 'rename') onRename();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Переименовать'),
                    ),
                    PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              Divider(indent: AppSpacing.lg),
              ...category.subcategories.map(
                (sub) => ListTile(
                  contentPadding: const EdgeInsets.only(left: AppSpacing.xl),
                  title: Text(sub, style: theme.textTheme.bodyLarge),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Действия с подкатегорией',
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onSelected: (value) {
                      if (value == 'rename') onRenameSubcategory(sub);
                      if (value == 'delete') onDeleteSubcategory(sub);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'rename',
                        child: Text('Переименовать'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: AppSpacing.xl),
                leading: Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: sona.onAccentSoft,
                ),
                title: Text(
                  'Добавить подкатегорию',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: onAddSubcategory,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _plural(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'ия';
    if ({2, 3, 4}.contains(count % 10) &&
        !{12, 13, 14}.contains(count % 100)) {
      return 'ии';
    }
    return 'ий';
  }
}
