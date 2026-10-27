import 'package:flutter/material.dart';

import '../validators/validators.dart';

/// Live checklist of the password rules, shown under any field where a
/// password is created or changed. It is a hint, not validation: the
/// validator still runs only on submit.
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final v = value.text;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Rule('At least ${PasswordRules.minLength} characters', PasswordRules.hasMinLength(v)),
            _Rule('One capital letter', PasswordRules.hasUppercase(v)),
            _Rule('One number', PasswordRules.hasNumber(v)),
            _Rule('One special character', PasswordRules.hasSpecial(v)),
            _Rule('No spaces', PasswordRules.noSpaces(v)),
          ],
        );
      },
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule(this.text, this.met);

  final String text;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = met ? Colors.green : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }
}
