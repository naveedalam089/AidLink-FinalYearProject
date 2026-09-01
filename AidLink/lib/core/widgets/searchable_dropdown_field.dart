// Purpose: Reusable searchable dropdown input widget for easy item selection.
// File: lib/core/widgets/searchable_dropdown_field.dart

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import '../constants/spacing.dart';
import '../constants/typography.dart';

class SearchableDropdownField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final List<String> items;
  final String? errorText;

  const SearchableDropdownField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    required this.items,
    this.errorText,
  });

  // --- Open modal bottom sheet with searchable item picker ---
  Future<void> _openPicker(BuildContext context) async {
    final searchController = TextEditingController();
    String query = '';

    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredItems = items.where((item) {
              return item.toLowerCase().contains(query.toLowerCase());
            }).toList();

            return Container(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(label, style: AppTypography.heading2),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search specialty',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setSheetState(() => query = value.trim());
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        return ListTile(
                          title: Text(item),
                          trailing: controller.text == item
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.primaryGreen,
                                )
                              : null,
                          onTap: () => Navigator.pop(sheetContext, item),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    if (selected != null) {
      controller.text = selected;
    }
  }

  // --- Build read-only text field with dropdown trigger ---
  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _openPicker(context),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
            filled: true,
            fillColor: Colors.white,
          ),
          style: AppTypography.bodyText,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ] else if (!hasValue) ...[
          const SizedBox(height: 4),
        ],
      ],
    );
  }
}
