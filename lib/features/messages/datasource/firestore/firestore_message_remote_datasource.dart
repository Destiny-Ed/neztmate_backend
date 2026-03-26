import 'package:dart_firebase_admin/firestore.dart';
import 'package:neztmate_backend/core/error.dart';

import 'package:neztmate_backend/features/messages/datasource/remote_datasource.dart';
import 'package:neztmate_backend/features/messages/models/chats_model.dart';
import 'package:neztmate_backend/features/messages/models/messages_model.dart';

class FirestoreMessageDataSource implements MessageRemoteDataSource {
  final Firestore firestore;

  FirestoreMessageDataSource(this.firestore);

  @override
  Future<MessageModel> sendMessage(MessageModel message) async {
    final docRef = firestore.collection('messages').doc();
    final newMessage = message.copyWith(id: docRef.id);
    await docRef.set(newMessage.toMap());
    return newMessage;
  }

  @override
  Future<List<MessageModel>> getConversation(
    String userId1,
    String userId2, {
    String? propertyId,
    int limit = 50,
  }) async {
    var query = firestore
        .collection('messages')
        .where('senderId', WhereFilter.equal, userId1)
        .where('receiverId', WhereFilter.equal, userId2)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }

    // Also get the reverse direction (user2 to user1)
    final snap1 = await query.get();

    query = firestore
        .collection('messages')
        .where('senderId', WhereFilter.equal, userId2)
        .where('receiverId', WhereFilter.equal, userId1)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (propertyId != null) {
      query = query.where('propertyId', WhereFilter.equal, propertyId);
    }

    final snap2 = await query.get();

    final allMessages = [...snap1.docs, ...snap2.docs];
    allMessages.sort((a, b) => (b.data()['createdAt'] as String).compareTo(a.data()['createdAt'] as String));

    return allMessages.take(limit).map((doc) {
      return MessageModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  @override
  Future<MessageModel> getMessageById(String id) async {
    final doc = await firestore.collection('messages').doc(id).get();
    if (!doc.exists) throw NotFoundException('Message', id);
    return MessageModel.fromMap(doc.data() as Map<String, dynamic>, id);
  }

  @override
  Future<void> markAsRead(String messageId, String readerId) async {
    await firestore.collection('messages').doc(messageId).update({
      'readAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> deleteMessage(String id) async {
    await firestore.collection('messages').doc(id).delete();
  }

  // In FirestoreMessageDataSource.dart
  @override
  Future<List<ChatSummaryModel>> getUserChats(String userId, {int limit = 20}) async {
    // Get all messages where user is sender OR receiver
    final sentSnap = await firestore
        .collection('messages')
        .where('senderId', WhereFilter.equal, userId)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2) // fetch more to deduplicate
        .get();

    final receivedSnap = await firestore
        .collection('messages')
        .where('receiverId', WhereFilter.equal, userId)
        .orderBy('createdAt', descending: true)
        .limit(limit * 2)
        .get();

    final allDocs = [...sentSnap.docs, ...receivedSnap.docs];

    // Group by the other user (create a unique chat key)
    final Map<String, List<DocumentSnapshot>> chatGroups = {};

    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final sender = data['senderId'] as String;
      final receiver = data['receiverId'] as String;
      final otherUserId = sender == userId ? receiver : sender;

      final key = otherUserId; // simple key for now

      chatGroups.putIfAbsent(key, () => []).add(doc);
    }

    final summaries = <ChatSummaryModel>[];

    for (var entry in chatGroups.entries) {
      final otherUserId = entry.key;
      final messages = entry.value;

      // Get the latest message
      messages.sort((a, b) {
        final timeA = (a.data() as Map)['createdAt'] as String;
        final timeB = (b.data() as Map)['createdAt'] as String;
        return timeB.compareTo(timeA);
      });

      final latestDoc = messages.first;
      final latestData = latestDoc.data() as Map<String, dynamic>;

      // Get other user info (you may want to cache this or join)
      // For simplicity, we'll use a placeholder. In production, fetch user once.
      final otherUserName = "User $otherUserId"; // Replace with real user fetch

      summaries.add(
        ChatSummaryModel(
          chatId: "${userId}_$otherUserId", // composite chat id
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          lastMessage: latestData['content'] as String,
          lastMessageTime: DateTime.parse(latestData['createdAt'] as String),
          isUnread: latestData['receiverId'] == userId && latestData['readAt'] == null,
          unreadCount: messages.where((m) {
            final d = m.data() as Map;
            return d['receiverId'] == userId && d['readAt'] == null;
          }).length,
          propertyId: latestData['propertyId'] as String?,
        ),
      );
    }

    // Sort by last message time
    summaries.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

    return summaries.take(limit).toList();
  }
}
