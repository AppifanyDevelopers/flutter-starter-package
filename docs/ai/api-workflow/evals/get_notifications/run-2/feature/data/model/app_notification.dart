class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    this.url,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final payload = data is Map ? data : const <dynamic, dynamic>{};
    return AppNotification(
      id: json['id'] as int? ?? 0,
      title: payload['title']?.toString() ?? '',
      body: payload['body']?.toString() ?? '',
      readAt: json['read_at']?.toString(),
      url: json['url']?.toString(),
    );
  }

  final int id;
  final String title;
  final String body;

  /// Null means unread.
  final String? readAt;

  /// Not navigated to yet; only used to decide whether a tap marks as read.
  final String? url;

  bool get isRead => readAt != null;

  AppNotification copyWith({String? readAt}) => AppNotification(
        id: id,
        title: title,
        body: body,
        readAt: readAt ?? this.readAt,
        url: url,
      );
}

class NotificationsPage {
  const NotificationsPage({required this.items, required this.hasMore});

  final List<AppNotification> items;
  final bool hasMore;
}
