import 'package:url_launcher/url_launcher.dart';

/// Centralizes `url_launcher` calls -- screens shouldn't call `launchUrl`
/// directly, so every link opens the same way.
abstract class UrlLauncherUtils {
  UrlLauncherUtils._();

  static Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> call(String phoneNumber) => openUrl('tel:$phoneNumber');

  static Future<void> email(String address, {String? subject}) {
    final query = subject == null ? '' : '?subject=${Uri.encodeComponent(subject)}';
    return openUrl('mailto:$address$query');
  }
}
