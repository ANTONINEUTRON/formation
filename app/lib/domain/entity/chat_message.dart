import 'package:file_picker/file_picker.dart';


class ChatMessage {
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.attachments = const [],
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<PlatformFile> attachments;
}

