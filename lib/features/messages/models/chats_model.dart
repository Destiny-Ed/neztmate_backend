class ChatSummaryModel {
  final String chatId; // Usually a composite of user1+user2 or a chat room id
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
  final String? otherPhone;
  final String lastMessage;
  final DateTime lastMessageTime;
  final bool isUnread;
  final int unreadCount;
  final String? propertyId; // Optional context

  ChatSummaryModel({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhotoUrl,
    this.otherPhone,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isUnread = false,
    this.unreadCount = 0,
    this.propertyId,
  });

  Map<String, dynamic> toMap() => {
    'chatId': chatId,
    'otherUserId': otherUserId,
    'otherUserName': otherUserName,
    'otherUserPhotoUrl': otherUserPhotoUrl,
    'otherPhone': otherPhone,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime.toIso8601String(),
    'isUnread': isUnread,
    'unreadCount': unreadCount,
    'propertyId': propertyId,
  };

  ChatSummaryModel copyWith({
    String? chatId,
    String? otherUserId,
    String? otherUserName,
    String? otherUserPhotoUrl,
    String? otherPhone,
    String? lastMessage,
    DateTime? lastMessageTime,
    bool? isUnread,
    int? unreadCount,
    String? propertyId,
  }) {
    return ChatSummaryModel(
      chatId: chatId ?? this.chatId,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserPhotoUrl: otherUserPhotoUrl ?? this.otherUserPhotoUrl,
      otherPhone: otherPhone ?? this.otherPhone,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isUnread: isUnread ?? this.isUnread,
      unreadCount: unreadCount ?? this.unreadCount,
      propertyId: propertyId ?? this.propertyId,
    );
  }
}
