import 'dart:io';

import 'package:flutter/material.dart';

/// Tap-to-pick-a-photo avatar, shared by signup (step 2) and Edit Profile.
/// [photoPath] is a local file path (this template's fake backend never
/// returns a remote photo URL) -- null shows a placeholder person icon.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.photoPath, required this.onTap, this.radius = 48});

  final String? photoPath;
  final VoidCallback onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photoPath = this.photoPath;
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundImage: photoPath == null ? null : FileImage(File(photoPath)),
            child: photoPath == null ? Icon(Icons.person, size: radius) : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: CircleAvatar(
              radius: radius * 0.32,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(Icons.camera_alt, size: radius * 0.32, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
