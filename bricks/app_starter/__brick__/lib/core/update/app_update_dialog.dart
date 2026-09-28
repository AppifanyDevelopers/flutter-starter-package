import 'package:flutter/material.dart';

class AppUpdateDialog {
  AppUpdateDialog._();

  static Future<void> show(BuildContext context, {required VoidCallback onUpdate}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Update available'),
        content: const Text(
          'A new version of this app is available. Please update to continue.',
        ),
        actions: [
          FilledButton(
            onPressed: onUpdate,
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}
