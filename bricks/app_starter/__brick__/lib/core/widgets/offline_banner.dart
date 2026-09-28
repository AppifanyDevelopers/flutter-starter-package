import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../connectivity/connectivity_service.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isOnline.value) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.error,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          'No internet connection',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onError, fontSize: 12),
        ),
      );
    });
  }
}
