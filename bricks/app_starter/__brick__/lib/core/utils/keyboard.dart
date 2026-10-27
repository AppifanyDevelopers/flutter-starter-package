import 'package:flutter/widgets.dart';

/// Call at the start of every submit action (Continue, Save, Verify...) so the
/// keyboard is gone before validation errors or a loading state appear.
void hideKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

/// Wraps the app so tapping any blank area dismisses the keyboard.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: hideKeyboard,
      child: child,
    );
  }
}
