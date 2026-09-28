import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Tracks whether the device currently has network connectivity. Registered
/// in AppInitializer; [init] is fire-and-forget (not awaited) so app boot
/// isn't blocked on a connectivity check -- [isOnline] starts `true` and
/// corrects itself within a moment if that's wrong.
class ConnectivityService extends GetxService {
  final isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  Future<void> init() async {
    final initial = await Connectivity().checkConnectivity();
    isOnline.value = _hasConnection(initial);
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = _hasConnection(results);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
