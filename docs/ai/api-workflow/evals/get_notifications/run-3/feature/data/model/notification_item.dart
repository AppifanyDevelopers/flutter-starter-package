/// One entry of `GET /notifications`. Only the outer `data.title` and
/// `data.body` are modelled; the nested `data.data` is ignored on purpose.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    this.url,
    this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final payload = json['data'] is Map ? json['data'] as Map : const {};
    return NotificationItem(
      id: json['id'] as int,
      title: payload['title']?.toString() ?? '',
      body: payload['body']?.toString() ?? '',
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      url: json['url'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  final int id;
  final String title;
  final String body;

  /// Null means unread.
  final DateTime? readAt;
  final String? url;
  final DateTime? createdAt;

  bool get isRead => readAt != null;

  NotificationItem asRead(DateTime at) => NotificationItem(
        id: id,
        title: title,
        body: body,
        readAt: at,
        url: url,
        createdAt: createdAt,
      );
}

/// One page of notifications plus whether another page exists
/// (from `meta`, `current_page < last_page`).
class NotificationPage {
  const NotificationPage({required this.items, required this.hasMore});

  final List<NotificationItem> items;
  final bool hasMore;
}
