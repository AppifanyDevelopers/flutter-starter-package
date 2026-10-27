import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

/// What the app may ask the user for.
enum AppPermission {
  camera('Camera', 'take a photo'),
  photos('Photos', 'choose a photo from your library'),
  notifications('Notifications', 'send you notifications');

  const AppPermission(this.label, this.purpose);

  final String label;

  /// Completes the sentence "Allow access in Settings so the app can ...".
  final String purpose;
}

enum PermissionOutcome { granted, denied, permanentlyDenied }

/// The platform seam: swap [Permissions.gateway] in tests.
abstract class PermissionGateway {
  Future<PermissionOutcome> status(AppPermission permission);
  Future<PermissionOutcome> request(AppPermission permission);
  Future<bool> openSettings();
}

class PermissionHandlerGateway implements PermissionGateway {
  Permission _map(AppPermission p) => switch (p) {
        AppPermission.camera => Permission.camera,
        AppPermission.photos => Permission.photos,
        AppPermission.notifications => Permission.notification,
      };

  PermissionOutcome _outcome(PermissionStatus s) {
    if (s.isGranted || s.isLimited || s.isProvisional) return PermissionOutcome.granted;
    if (s.isPermanentlyDenied || s.isRestricted) return PermissionOutcome.permanentlyDenied;
    return PermissionOutcome.denied;
  }

  @override
  Future<PermissionOutcome> status(AppPermission permission) async => _outcome(await _map(permission).status);

  @override
  Future<PermissionOutcome> request(AppPermission permission) async => _outcome(await _map(permission).request());

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// One place to ask for a permission, with the same behaviour everywhere:
///
/// * already allowed -> true, nothing shown;
/// * not yet decided -> the system prompt;
/// * denied for good (the system will not prompt again) -> a dialog explaining
///   why it is needed with a button to the app's Settings page.
abstract class Permissions {
  Permissions._();

  static PermissionGateway gateway = PermissionHandlerGateway();

  /// Returns whether [permission] is granted when this completes.
  static Future<bool> ensure(AppPermission permission) async {
    var outcome = await gateway.status(permission);
    if (outcome == PermissionOutcome.granted) return true;

    if (outcome == PermissionOutcome.denied) {
      outcome = await gateway.request(permission);
      if (outcome == PermissionOutcome.granted) return true;
    }

    if (outcome == PermissionOutcome.permanentlyDenied) {
      await _offerSettings(permission);
    }
    return false;
  }

  static Future<void> _offerSettings(AppPermission permission) async {
    final openSettings = await Get.dialog<bool>(
      AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: Text('${permission.label} access is off'),
        content: Text(
          'Allow ${permission.label.toLowerCase()} access in Settings so the app can ${permission.purpose}.',
        ),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Not now')),
          FilledButton(onPressed: () => Get.back(result: true), child: const Text('Open Settings')),
        ],
      ),
    );
    if (openSettings == true) await gateway.openSettings();
  }
}
