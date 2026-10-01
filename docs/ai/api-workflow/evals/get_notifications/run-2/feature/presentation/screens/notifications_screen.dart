import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      body: Obx(
        () => controller.state.value.showWidget(
          loading: (_) => const _NotificationsShimmerList(),
          error: (_) => AppErrorWidget(message: controller.errorMessage.value, onRetry: controller.load),
          orElse: (_) => RefreshIndicator(
            onRefresh: controller.refreshList,
            child: controller.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
                      const Center(child: Text('No notifications yet.')),
                    ],
                  )
                : ListView.separated(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.notifications.length + 1,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index == controller.notifications.length) {
                        return const _FooterRow();
                      }
                      final item = controller.notifications[index];
                      return ListTile(
                        leading: item.isRead
                            ? const SizedBox(width: 10)
                            : Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary),
                        title: Text(
                          item.title,
                          style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Text(item.body),
                        onTap: () => controller.onTap(item),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _FooterRow extends GetView<NotificationsController> {
  const _FooterRow();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: AppLoadingWidget.small()),
        );
      }
      if (controller.loadMoreFailed.value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load more notifications.'),
                TextButton(onPressed: controller.retryLoadMore, child: const Text('Retry')),
              ],
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    });
  }
}

class _NotificationsShimmerList extends StatelessWidget {
  const _NotificationsShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppShimmer.box(height: 64),
    );
  }
}
