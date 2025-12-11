import 'package:flutter/material.dart';
import '../../data/resources/gene/app_colors.dart';
import '../../data/resources/gene/app_dimensions.dart';
import '../../data/resources/gene/app_text_styles.dart';

/// Info Field Type
enum InfoFieldType {
  readonly, // Display only
  editable, // Can be edited with tap
  action, // Has custom action
}

/// Info Field Configuration
class InfoField {
  final String label;
  final String value;
  final InfoFieldType type;
  final VoidCallback? onTap;
  final IconData? icon;

  const InfoField({
    required this.label,
    required this.value,
    this.type = InfoFieldType.readonly,
    this.onTap,
    this.icon,
  });

  /// Create readonly field
  factory InfoField.readonly({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return InfoField(
      label: label,
      value: value,
      type: InfoFieldType.readonly,
      icon: icon,
    );
  }

  /// Create editable field
  factory InfoField.editable({
    required String label,
    required String value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InfoField(
      label: label,
      value: value,
      type: InfoFieldType.editable,
      onTap: onTap,
      icon: icon,
    );
  }

  /// Create action field
  factory InfoField.action({
    required String label,
    required String value,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return InfoField(
      label: label,
      value: value,
      type: InfoFieldType.action,
      onTap: onTap,
      icon: icon,
    );
  }
}

/// Reusable Info Card Component
///
/// Displays structured information in a card format with support for:
/// - Readonly fields
/// - Editable fields (with tap interaction)
/// - Custom action fields
/// - Optional header and footer widgets
class InfoCard extends StatelessWidget {
  final String title;
  final List<InfoField> fields;
  final Widget? headerWidget;
  final Widget? footerWidget;
  final EdgeInsets? padding;
  final bool showDividers;

  const InfoCard({
    super.key,
    required this.title,
    required this.fields,
    this.headerWidget,
    this.footerWidget,
    this.padding,
    this.showDividers = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? AppDimensions.paddingAllLarge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          if (headerWidget != null)
            headerWidget!
          else
            Text(title, style: AppTextStyles.body1Bold),

          if (fields.isNotEmpty) SizedBox(height: AppDimensions.spacingSmall),

          // Fields
          ...fields.asMap().entries.map((entry) {
            final index = entry.key;
            final field = entry.value;
            final isLast = index == fields.length - 1;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildField(field),
                if (!isLast && showDividers) const Divider(height: 24),
                if (!isLast && !showDividers)
                  SizedBox(height: AppDimensions.spacingSmall),
              ],
            );
          }),

          // Footer
          if (footerWidget != null) ...[
            SizedBox(height: AppDimensions.spacingMedium),
            footerWidget!,
          ],
        ],
      ),
    );
  }

  Widget _buildField(InfoField field) {
    final widget = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (field.icon != null) ...[
              Icon(field.icon, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
            ],
            Text(field.label, style: AppTextStyles.body2Secondary),
          ],
        ),
        SizedBox(width: AppDimensions.spacingMedium),
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  field.value,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.body2,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              if (field.type == InfoFieldType.editable ||
                  field.type == InfoFieldType.action) ...[
                const SizedBox(width: 4),
                Icon(
                  field.type == InfoFieldType.editable
                      ? Icons.edit_outlined
                      : Icons.chevron_right,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    // Wrap with InkWell if interactive
    if (field.type != InfoFieldType.readonly && field.onTap != null) {
      return InkWell(onTap: field.onTap, child: widget);
    }

    return widget;
  }
}

/// Info Card with Multi-line Text Field
///
/// Specialized variant for displaying a multi-line text field
/// (e.g., medical history, description)
class InfoCardWithTextBlock extends StatelessWidget {
  final String title;
  final List<InfoField>? fields;
  final String textBlockLabel;
  final String textBlockValue;
  final VoidCallback? onTextBlockTap;
  final bool isTextBlockEditable;

  const InfoCardWithTextBlock({
    super.key,
    required this.title,
    this.fields,
    required this.textBlockLabel,
    required this.textBlockValue,
    this.onTextBlockTap,
    this.isTextBlockEditable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppDimensions.paddingAllLarge,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.borderRadiusLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(title, style: AppTextStyles.body1Bold),

          // Fields
          if (fields != null && fields!.isNotEmpty) ...[
            SizedBox(height: AppDimensions.spacingSmall),
            ...fields!.asMap().entries.map((entry) {
              final index = entry.key;
              final field = entry.value;

              return Column(
                children: [
                  _buildFieldRow(field),
                  if (index < fields!.length - 1) const Divider(height: 24),
                ],
              );
            }),
            const Divider(height: 24),
          ] else
            SizedBox(height: AppDimensions.spacingSmall),

          // Text Block
          Text(textBlockLabel, style: AppTextStyles.body2Bold),
          SizedBox(height: AppDimensions.spacingSmall),
          InkWell(
            onTap: isTextBlockEditable ? onTextBlockTap : null,
            child: Text(textBlockValue, style: AppTextStyles.body2Secondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(InfoField field) {
    final widget = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(field.label, style: AppTextStyles.body2Secondary),
        SizedBox(width: AppDimensions.spacingMedium),
        Flexible(
          child: Text(
            field.value,
            textAlign: TextAlign.right,
            style: AppTextStyles.body2,
          ),
        ),
      ],
    );

    if (field.onTap != null) {
      return InkWell(onTap: field.onTap, child: widget);
    }

    return widget;
  }
}
