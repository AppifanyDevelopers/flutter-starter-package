import 'package:flutter/material.dart';

import '../utils/keyboard.dart';
import 'app_loading_widget.dart';

/// Primary CTA button used across the app, with a built-in loading spinner
/// state so screens don't have to wrap buttons themselves.
class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outline = false,
  });

  const AppOutlinedButton.outline({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  }) : outline = true;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const AppLoadingWidget.small(color: Colors.white)
        : Text(label);

    final handler = onPressed;
    // Every Continue/Save/Verify press dismisses the keyboard first.
    final VoidCallback? onTap = isLoading || handler == null
        ? null
        : () {
            hideKeyboard();
            handler();
          };

    if (outline) {
      return OutlinedButton(onPressed: onTap, child: child);
    }
    return ElevatedButton(onPressed: onTap, child: child);
  }
}
