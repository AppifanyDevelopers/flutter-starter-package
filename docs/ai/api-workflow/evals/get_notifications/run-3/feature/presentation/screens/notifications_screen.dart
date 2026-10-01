import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../data/model/notification_item.dart';
import '../controllers/notifications_controller.dart';

class NotificationsScreen extends GetView<NotificationsController> {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Notifications',
      padding: EdgeInsets.zero,
      body: Obx(
        () => controller.state.value.showWidget(
          loading: (_) => const _NotificationsShimmerList(),
          error: (_) => AppErrorWidget(
            message: 'Could not load notifications.',
            onRetry: controller.load,
          ),
          orElse: (_) => RefreshIndicator(
            onRefresh: controller.reload,
            child: controller.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).height * 0.5,
                        child: const Center(child: Text('No notifications yet.')),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.notifications.length + 1,
                    itemBuilder: (context, index) {
                      if (index == controller.notifications.length) {
                        return const _Footer();
                      }
                      final item = controller.notifications[index];
                      return _NotificationTile(item: item, onTap: () => controller.onTap(item));
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: item.isRead
          ? const SizedBox(width: 10)
          : Container(
              key: const Key('unread_indicator'),
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
            ),
      title: Text(
        item.title,
        style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold),
      ),
      subtitle: Text(item.body),
    );
  }
}

class _Footer extends GetView<NotificationsController> {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.loadMoreFailed.value) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load more.'),
              TextButton(onPressed: controller.retryLoadMore, child: const Text('Retry')),
            ],
          ),
        );
      }
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(child: AppLoadingWidget.small()),
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
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppShimmer.box(height: 56),
    );
  }
}
