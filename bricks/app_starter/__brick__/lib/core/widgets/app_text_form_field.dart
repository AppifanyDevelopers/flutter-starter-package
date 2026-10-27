import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The one text field every form uses.
///
/// Validation runs only when the form is submitted (`formKey.validate()`),
/// never while the user types -- `autovalidateMode` is pinned to `disabled`
/// here so no screen can accidentally turn it on.
class AppTextFormField extends StatelessWidget {
  const AppTextFormField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.suffixIcon,
    this.errorText,
    this.maxLines = 1,
    this.enabled = true,
    this.onFieldSubmitted,
  });

  /// A person's name: name keyboard, each word capitalised.
  const AppTextFormField.name({
    super.key,
    this.label = 'Full name',
    this.controller,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.enabled = true,
    this.onFieldSubmitted,
  })  : obscureText = false,
        keyboardType = TextInputType.name,
        textCapitalization = TextCapitalization.words,
        inputFormatters = null,
        autofillHints = const [AutofillHints.name],
        suffixIcon = null,
        maxLines = 1;

  /// An email address: email keyboard, no spaces, no auto-capitalisation.
  AppTextFormField.email({
    super.key,
    this.label = 'Email',
    this.controller,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.enabled = true,
    this.onFieldSubmitted,
  })  : obscureText = false,
        keyboardType = TextInputType.emailAddress,
        textCapitalization = TextCapitalization.none,
        inputFormatters = [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        autofillHints = const [AutofillHints.email],
        suffixIcon = null,
        maxLines = 1;

  /// A phone number: phone keyboard, digits and common separators only.
  AppTextFormField.phone({
    super.key,
    this.label = 'Phone number',
    this.controller,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.errorText,
    this.enabled = true,
    this.onFieldSubmitted,
  })  : obscureText = false,
        keyboardType = TextInputType.phone,
        textCapitalization = TextCapitalization.none,
        inputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))],
        autofillHints = const [AutofillHints.telephoneNumber],
        suffixIcon = null,
        maxLines = 1;

  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;

  /// A server-side error (e.g. a 422 field error), shown under the field.
  final String? errorText;
  final int maxLines;
  final bool enabled;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      autovalidateMode: AutovalidateMode.disabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      maxLines: maxLines,
      enabled: enabled,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        errorText: errorText,
      ),
    );
  }
}
