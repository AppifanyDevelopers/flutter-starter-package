import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../controllers/faq_controller.dart';

class FaqScreen extends GetView<FaqController> {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'FAQ',
      body: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search FAQs',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: controller.search,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Obx(
              () => controller.state.value.showWidget(
                loading: (_) => const _FaqShimmerList(),
                error: (_) => AppErrorWidget(message: 'Could not load FAQs.', onRetry: controller.retry),
                orElse: (_) => controller.faqs.isEmpty
                    ? const Center(child: Text('No FAQs match your search.'))
                    : RefreshIndicator(
                        onRefresh: controller.reload,
                        child: ListView.separated(
                          controller: controller.scrollController,
                          itemCount: controller.faqs.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            if (index == controller.faqs.length) {
                              return Obx(
                                () => controller.isLoadingMore.value
                                    ? const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Center(child: AppLoadingWidget.small()),
                                      )
                                    : const SizedBox.shrink(),
                              );
                            }
                            final faq = controller.faqs[index];
                            return ExpansionTile(
                              title: Text(faq.question),
                              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              children: [Align(alignment: Alignment.centerLeft, child: Text(faq.answer))],
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqShimmerList extends StatelessWidget {
  const _FaqShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppShimmer.box(height: 48),
    );
  }
}
