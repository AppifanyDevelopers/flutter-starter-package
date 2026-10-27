import 'package:flutter/widgets.dart';

import '../../features/app/app_entry_point.dart';
import '../config/app_configuration.dart';

class StagingEntryPoint extends StatelessWidget {
  const StagingEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    AppConfiguration.current = AppConfiguration.staging;
    return const AppEntryPoint();
  }
}

class DiEntryPoint extends StatelessWidget {
  const DiEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    AppConfiguration.current = AppConfiguration.di;
    return const AppEntryPoint();
  }
}

class ProductionEntryPoint extends StatelessWidget {
  const ProductionEntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    AppConfiguration.current = AppConfiguration.production;
    return const AppEntryPoint();
  }
}
