import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/the_states.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../data/model/app_notification.dart';
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
          error: (_) => AppErrorWidget(message: 'Could not load notifications.', onRetry: controller.load),
          orElse: (_) => RefreshIndicator(
            onRefresh: controller.pullToRefresh,
            child: controller.notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No notifications yet.')),
                    ],
                  )
                : ListView.separated(
                    controller: controller.scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.notifications.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == controller.notifications.length) return const _FooterRow();
                      final item = controller.notifications[index];
                      return _NotificationTile(
                        notification: item,
                        onTap: () => controller.onTapNotification(item),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return ListTile(
      onTap: onTap,
      leading: unread
          ? Icon(Icons.circle, size: 12, color: Theme.of(context).colorScheme.primary)
          : const SizedBox(width: 12),
      title: Text(
        notification.title,
        style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text(notification.body),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Could not load more.'),
              TextButton(onPressed: controller.retryLoadMore, child: const Text('Retry')),
            ],
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
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => AppShimmer.box(height: 64),
    );
  }
}
