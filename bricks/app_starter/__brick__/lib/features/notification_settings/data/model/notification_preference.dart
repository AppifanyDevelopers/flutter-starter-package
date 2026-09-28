class NotificationPreference {
  const NotificationPreference({required this.key, required this.label, required this.isEnabled});

  final String key;
  final String label;
  final bool isEnabled;

  NotificationPreference copyWith({bool? isEnabled}) => NotificationPreference(
        key: key,
        label: label,
        isEnabled: isEnabled ?? this.isEnabled,
      );
}
