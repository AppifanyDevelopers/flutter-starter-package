import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../controllers/terms_and_conditions_controller.dart';

class TermsAndConditionsScreen extends GetView<TermsAndConditionsController> {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Terms & Conditions',
      body: Obx(
        () => controller.state.value.showWidget(
          loading: (_) => const TextContentShimmer(),
          error: (_) => AppErrorWidget(message: 'Could not load this page.', onRetry: controller.retry),
          orElse: (_) => RefreshIndicator(
            onRefresh: controller.reload,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: HtmlWidget(controller.html.value),
            ),
          ),
        ),
      ),
    );
  }
}
