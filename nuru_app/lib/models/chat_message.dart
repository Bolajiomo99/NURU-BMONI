import 'action_data.dart';

class ChatMessageItem {
  final int? id;
  final String role; // 'user' or 'assistant'
  final String content;
  final String? actionType;
  final NuruAction? action;
  final DateTime timestamp;

  ChatMessageItem({
    this.id,
    required this.role,
    required this.content,
    this.actionType,
    this.action,
    required this.timestamp,
  });

  bool get isUser => role == 'user';
  bool get hasAction => action != null && action!.type.isNotEmpty;

  factory ChatMessageItem.fromJson(Map<String, dynamic> json) {
    NuruAction? actionObj;
    if (json['action'] != null) {
      actionObj = NuruAction.fromJson(json['action']);
    } else if (json['action_data'] != null) {
      actionObj = NuruAction(
        type: json['action_type'] ?? '',
        data: Map<String, dynamic>.from(json['action_data']),
      );
    }

    return ChatMessageItem(
      id: json['id'],
      role: json['role'] ?? 'assistant',
      content: json['content'] ?? json['message'] ?? '',
      actionType: json['action_type'] ?? (actionObj?.type),
      action: actionObj,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
