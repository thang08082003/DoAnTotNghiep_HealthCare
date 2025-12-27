class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  // Attachment fields (optional)
  final String? type; // 'text' | 'image' | 'file'
  final String? mediaUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.createdAt,
    required this.isRead,
    this.type,
    this.mediaUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
  });

  factory ChatMessage.fromJson(String id, Map<String, dynamic> json) {
    return ChatMessage(
      id: id,
      senderId: json['senderId'] as String,
      receiverId: json['receiverId'] as String,
      text: json['text'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      isRead: (json['isRead'] as bool?) ?? false,
      type: json['type'] as String?,
      mediaUrl: json['mediaUrl'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: (json['fileSize'] is int) ? json['fileSize'] as int : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (type != null) 'type': type,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
    };
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
    // Firestore Timestamp has toDate()
    try {
      final toDate = (v as dynamic).toDate;
      if (toDate is Function) return toDate();
    } catch (_) {}
    return DateTime.now();
  }
}

extension ChatMessageX on ChatMessage {
  String get kind => (type ?? (mediaUrl != null ? 'image' : 'text'));
  bool get isImage => kind == 'image';
  bool get isVideo => kind == 'video';
  bool get isFile => kind == 'file';
  bool get isText => kind == 'text';
}
