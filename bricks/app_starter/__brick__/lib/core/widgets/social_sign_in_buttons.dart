import 'dart:io';

import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// "Continue with Google/Apple" -- a dumb, reusable widget shared by Login
/// and Signup (both do the exact same one-shot action, see
/// `core/auth/social_auth_service.dart`). Apple only renders on iOS --
/// Android/Web need a hosted redirect this template doesn't have.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.onGoogleTap,
    required this.onAppleTap,
  });

  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: Theme.of(context).textTheme.labelMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onGoogleTap,
          // A generic icon, not Google's trademarked "G" logo -- swap in a
          // branded asset before shipping (see docs/POST_GEN_MANUAL_STEPS.md).
          icon: const Icon(Icons.g_mobiledata, size: 28),
          label: const Text('Continue with Google'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          SignInWithAppleButton(onPressed: onAppleTap, height: 48),
        ],
      ],
    );
  }
}
