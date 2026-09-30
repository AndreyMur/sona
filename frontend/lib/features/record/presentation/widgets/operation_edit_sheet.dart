import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/models/category.dart';
import '../../../../domain/models/operation.dart';

/// Открывает шторку ручного изменения распознанной операции.
Future<ParsedOperation?> showOperationEditSheet(
  BuildContext context, {
  required ParsedOperation operation,
}) {
  return showModalBottomSheet<ParsedOperation>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _OperationEditSheet(operation: operation),
  );
}

class _OperationEditSheet extends ConsumerStatefulWidget {
  const _OperationEditSheet({required this.operation});

  final ParsedOperation operation;

  @override
  ConsumerState<_OperationEditSheet> createState() =>
      _OperationEditSheetState();
}

class _OperationEditSheetState extends ConsumerState<_OperationEditSheet> {
  late OperationType _type;
  late final TextEditingController _amountController;
  late String _category;
  String? _subcategory;
  late DateTime _date;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final operation = widget.operation;
    _type = operation.type;
    _category = operation.category;
    _subcategory = operation.subcategory;
    _date = operation.date;
    _amountController = TextEditingController(
      text: operation.amount.toStringAsFixed(
        operation.amount.truncateToDouble() == operation.amount ? 0 : 2,
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final current = _findCategory(categories, _category);
    final subcategories = current?.subcategories ?? const <String>[];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Изменить операцию', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<OperationType>(
            segments: const [
              ButtonSegment(
                value: OperationType.expense,
                label: Text('Расход'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: OperationType.income,
                label: Text('Доход'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Сумма, ₽',
              errorText: _amountError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _category.isEmpty ? null : _category,
            decoration: const InputDecoration(labelText: 'Категория'),
            items: categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.name,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _category = value;
                _subcategory = null;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: subcategories.contains(_subcategory)
                ? _subcategory
                : null,
            decoration: const InputDecoration(labelText: 'Подкатегория'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Без подкатегории')),
              ...subcategories.map(
                (sub) => DropdownMenuItem<String?>(value: sub, child: Text(sub)),
              ),
            ],
            onChanged: (value) => setState(() => _subcategory = value),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_rounded, size: 18),
            label: Text(_dateLabel()),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _save,
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Category? _findCategory(List<Category> categories, String name) {
    for (final category in categories) {
      if (category.name == name) return category;
    }
    return null;
  }

  String _dateLabel() {
    final now = DateTime.now();
    final isToday =
        _date.year == now.year && _date.month == now.month && _date.day == now.day;
    if (isToday) return 'Сегодня, ${_date.day}.${_date.month}.${_date.year}';
    return '${_date.day}.${_date.month}.${_date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _save() {
    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '.').trim(),
    );
    if (amount == null || amount <= 0) {
      setState(() => _amountError = 'Введите сумму больше нуля');
      return;
    }
    Navigator.of(context).pop(
      widget.operation.copyWith(
        type: _type,
        amount: amount,
        category: _category,
        subcategory: _subcategory,
        date: _date,
        confidence: 1,
      ),
    );
  }
}
