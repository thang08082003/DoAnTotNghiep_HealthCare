import 'package:flutter/material.dart';

/// A reusable password input field with visibility toggle.
///
/// Features:
/// - Password obscuring with toggle button
/// - Optional validation
/// - Consistent styling with OutlineInputBorder
/// - Eye icon for visibility toggle
/// - Support for custom labels
///
/// Usage:
/// ```dart
/// final controller = TextEditingController();
/// bool obscure = true;
///
/// PasswordField(
///   label: 'Mật khẩu',
///   controller: controller,
///   obscure: obscure,
///   onToggle: () => setState(() => obscure = !obscure),
///   validator: (value) {
///     if (value == null || value.isEmpty) {
///       return 'Vui lòng nhập mật khẩu';
///     }
///     if (value.length < 6) {
///       return 'Mật khẩu phải ít nhất 6 ký tự';
///     }
///     return null;
///   },
/// )
/// ```
class PasswordField extends StatelessWidget {
  /// Label text displayed above the field
  final String label;

  /// Controller for the text input
  final TextEditingController controller;

  /// Whether the password is currently obscured
  final bool obscure;

  /// Callback when visibility toggle button is pressed
  final VoidCallback onToggle;

  /// Optional validation function
  final String? Function(String?)? validator;

  /// Optional hint text
  final String? hintText;

  /// Whether the field is enabled
  final bool enabled;

  /// Optional prefix icon
  final Widget? prefixIcon;

  /// Auto-focus on mount
  final bool autofocus;

  /// Text input action (e.g., TextInputAction.next)
  final TextInputAction? textInputAction;

  /// Callback when field is submitted
  final VoidCallback? onFieldSubmitted;

  const PasswordField({
    super.key,
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.hintText,
    this.enabled = true,
    this.prefixIcon,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      enabled: enabled,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted != null
          ? (_) => onFieldSubmitted!()
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        prefixIcon: prefixIcon,
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
          tooltip: obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
        ),
      ),
    );
  }
}
