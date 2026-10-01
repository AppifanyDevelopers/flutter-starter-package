/// One entry of `GET /notifications`. Only the outer `data.title` and
/// `data.body` are modelled; the nested `data.data` and `url` are ignored.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final payload = data is Map ? data : const <String, dynamic>{};
    final rawReadAt = json['read_at'];
    return AppNotification(
      id: json['id'] as int? ?? 0,
      title: payload['title']?.toString() ?? '',
      body: payload['body']?.toString() ?? '',
      readAt: rawReadAt is String ? DateTime.tryParse(rawReadAt) : null,
    );
  }

  final int id;
  final String title;
  final String body;

  /// Null means unread.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) =>
      AppNotification(id: id, title: title, body: body, readAt: at);

  AppNotification markedUnread() => AppNotification(id: id, title: title, body: body);
}

/// One page of notifications plus whether another page follows.
class NotificationsPage {
  const NotificationsPage({required this.items, required this.hasMore});

  final List<AppNotification> items;
  final bool hasMore;
}
