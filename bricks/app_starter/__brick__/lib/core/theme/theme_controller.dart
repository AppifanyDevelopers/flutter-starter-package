import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  ThemeController({GetStorage? box}) : _box = box ?? GetStorage();

  static const _key = 'theme_mode';

  final GetStorage _box;
  final themeMode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _box.read<String>(_key);
    themeMode.value = ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    await _box.write(_key, mode.name);
  }
}
