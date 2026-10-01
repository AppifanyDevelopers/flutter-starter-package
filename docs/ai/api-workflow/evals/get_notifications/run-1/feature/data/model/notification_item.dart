/// One entry of `GET /notifications`. Only the outer `data` object (title and
/// body) is modelled; the nested `data.data` is intentionally ignored.
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    this.url,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    final content =
        data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return NotificationItem(
      id: json['id'] as int,
      title: content['title'] as String? ?? '',
      body: content['body'] as String? ?? '',
      readAt: json['read_at'] as String?,
      url: json['url'] as String?,
    );
  }

  final int id;
  final String title;
  final String body;

  /// Null means unread.
  final String? readAt;
  final String? url;

  bool get isRead => readAt != null;

  NotificationItem copyWith({String? readAt, bool clearReadAt = false}) =>
      NotificationItem(
        id: id,
        title: title,
        body: body,
        readAt: clearReadAt ? null : (readAt ?? this.readAt),
        url: url,
      );
}
