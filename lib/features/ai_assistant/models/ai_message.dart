import 'package:uuid/uuid.dart';

enum MessageRole { user, assistant, system }

class AiMessage {
  final String id;
  final MessageRole role;
  final String text;
  final DateTime timestamp;
  final String? actionType; // 'reminder', 'expense', 'income', 'image'
  final Map<String, dynamic>? actionPayload;
  final String? imageUrl;
  final String? base64Data;
  final String? referenceImagePath;
  final bool isExecuted;
  final String? executionStatus;
  final bool isLoading;

  AiMessage({
    String? id,
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.actionType,
    this.actionPayload,
    this.imageUrl,
    this.base64Data,
    this.referenceImagePath,
    this.isExecuted = false,
    this.executionStatus,
    this.isLoading = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  AiMessage copyWith({
    String? id,
    MessageRole? role,
    String? text,
    DateTime? timestamp,
    String? actionType,
    Map<String, dynamic>? actionPayload,
    String? imageUrl,
    String? base64Data,
    String? referenceImagePath,
    bool? isExecuted,
    String? executionStatus,
    bool? isLoading,
  }) {
    return AiMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      actionType: actionType ?? this.actionType,
      actionPayload: actionPayload ?? this.actionPayload,
      imageUrl: imageUrl ?? this.imageUrl,
      base64Data: base64Data ?? this.base64Data,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      isExecuted: isExecuted ?? this.isExecuted,
      executionStatus: executionStatus ?? this.executionStatus,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
