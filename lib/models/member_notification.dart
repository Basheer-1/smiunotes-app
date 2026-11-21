/// Strict own-account notifications returned by an authenticated session.
class MemberNotification {
  const MemberNotification({
    required this.id, required this.category, required this.title,
    required this.message, required this.createdAt, required this.isRead,
  });
  final String id, category, title, message;
  final DateTime createdAt;
  final bool isRead;

  factory MemberNotification.fromJson(Map<String, dynamic> json) {
    final id = json['id'], category = json['category'];
    final title = json['title'], message = json['message'];
    final createdRaw = json['created_at'];
    final readRaw = json['read_at'];
    final created = createdRaw is String ? DateTime.tryParse(createdRaw) : null;
    final readAt = readRaw is String ? DateTime.tryParse(readRaw) : null;
    if (id is! String || id.isEmpty || category is! String ||
        category.isEmpty || title is! String || title.trim().isEmpty ||
        message is! String || message.trim().isEmpty || created == null ||
        (readRaw != null && readAt == null)) {
      throw const FormatException('Invalid notification.');
    }
    return MemberNotification(
      id: id, category: category, title: title, message: message,
      createdAt: created, isRead: readAt != null,
    );
  }
}

class MemberNotificationInbox {
  const MemberNotificationInbox({required this.items, required this.unread});
  final List<MemberNotification> items;
  final int unread;
  factory MemberNotificationInbox.fromJson(Map<String, dynamic> json) {
    final raw = json['items'], count = json['unread'];
    if (raw is! List || count is! num || count < 0 || count.toInt() != count) {
      throw const FormatException('Invalid notification inbox.');
    }
    return MemberNotificationInbox(
      unread: count.toInt(),
      items: raw.map((entry) {
        if (entry is! Map<String, dynamic>) {
          throw const FormatException('Invalid notification item.');
        }
        return MemberNotification.fromJson(entry);
      }).toList(growable: false),
    );
  }
}
