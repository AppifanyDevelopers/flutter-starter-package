import 'package:flutter/widgets.dart';

import '../../core/di/app_initializer.dart';
import 'my_app.dart';

class AppEntryPoint extends StatelessWidget {
  const AppEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    AppInitializer.init();
    return const MyApp();
  }
}
