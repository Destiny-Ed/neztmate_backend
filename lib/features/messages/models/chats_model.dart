class ChatSummaryModel {
  final String chatId; // Usually a composite of user1+user2 or a chat room id
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhotoUrl;
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
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime.toIso8601String(),
    'isUnread': isUnread,
    'unreadCount': unreadCount,
    'propertyId': propertyId,
  };
}
