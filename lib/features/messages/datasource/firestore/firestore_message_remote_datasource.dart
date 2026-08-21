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
    String? partnerId,
    int limit = 50,
  }) async {
    Future<List<QueryDocumentSnapshot>> fetch(String from, String to) async {
      var query = firestore
          .collection('messages')
          .where('senderId', WhereFilter.equal, from)
          .where('receiverId', WhereFilter.equal, to);

      if (partnerId != null && partnerId.isNotEmpty) {
        query = query.where('partnerId', WhereFilter.equal, partnerId);
      }
      if (propertyId != null && propertyId.isNotEmpty) {
        query = query.where('propertyId', WhereFilter.equal, propertyId);
      }

      final snap = await query.orderBy('createdAt', descending: true).limit(limit).get();
      return snap.docs;
    }

    final snap1 = await fetch(userId1, userId2);
    final snap2 = await fetch(userId2, userId1);

    final allMessages = [...snap1, ...snap2];
    allMessages.sort((a, b) {
      final ta = (a.data() as Map)['createdAt'] as String? ?? '';
      final tb = (b.data() as Map)['createdAt'] as String? ?? '';
      return tb.compareTo(ta);
    });

    return allMessages.take(limit).map((doc) {
      return MessageModel.fromMap(doc.data() as Map<String, dynamic>);
    }).toList();
  }

  @override
  Future<MessageModel> getMessageById(String id) async {
    final doc = await firestore.collection('messages').doc(id).get();
    if (!doc.exists) throw NotFoundException('Message', id);
    return MessageModel.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Future<void> deleteMessage(String id) async {
    await firestore.collection('messages').doc(id).delete();
  }

  @override
  Future<List<ChatSummaryModel>> getUserChats(String userId, {String? partnerId, int limit = 20}) async {
    Future<QuerySnapshot> sent() async {
      var q = firestore.collection('messages').where('senderId', WhereFilter.equal, userId);
      if (partnerId != null && partnerId.isNotEmpty) {
        q = q.where('partnerId', WhereFilter.equal, partnerId);
      }
      return q.orderBy('createdAt', descending: true).limit(limit * 2).get();
    }

    Future<QuerySnapshot> received() async {
      var q = firestore.collection('messages').where('receiverId', WhereFilter.equal, userId);
      if (partnerId != null && partnerId.isNotEmpty) {
        q = q.where('partnerId', WhereFilter.equal, partnerId);
      }
      return q.orderBy('createdAt', descending: true).limit(limit * 2).get();
    }

    final sentSnap = await sent();
    final receivedSnap = await received();
    final allDocs = [...sentSnap.docs, ...receivedSnap.docs];

    final Map<String, List<DocumentSnapshot>> chatGroups = {};

    for (final doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final sender = data['senderId'] as String;
      final receiver = data['receiverId'] as String;
      final otherUserId = sender == userId ? receiver : sender;
      chatGroups.putIfAbsent(otherUserId, () => []).add(doc);
    }

    final summaries = <ChatSummaryModel>[];

    for (final entry in chatGroups.entries) {
      final otherUserId = entry.key;
      final messages = entry.value;

      messages.sort((a, b) {
        final timeA = (a.data() as Map)['createdAt'] as String? ?? '';
        final timeB = (b.data() as Map)['createdAt'] as String? ?? '';
        return timeB.compareTo(timeA);
      });

      final latestData = messages.first.data() as Map<String, dynamic>;

      summaries.add(
        ChatSummaryModel(
          chatId: '${userId}_$otherUserId',
          otherUserId: otherUserId,
          otherUserName: 'User $otherUserId', // replace with user fetch if you have it
          lastMessage: latestData['content'] as String? ?? '',
          lastMessageTime: DateTime.parse(latestData['createdAt'] as String),
          isUnread: latestData['receiverId'] == userId && latestData['readAt'] == null,
          unreadCount: messages.where((m) {
            final d = m.data() as Map;
            return d['receiverId'] == userId && d['readAt'] == null;
          }).length,
          propertyId: latestData['propertyId'] as String?,
          partnerId: latestData['partnerId'].toString(),
        ),
      );
    }

    summaries.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    return summaries.take(limit).toList();
  }

  @override
  Future<void> markChatAsRead(String chatId, String readerId) async {
    await firestore.collection('messages').doc(chatId).update({'readAt': DateTime.now().toIso8601String()});
  }

  @override
  Future<void> markConversationAsRead(String conversationId, String readerId) async {
    await firestore.collection('messages').doc(conversationId).update({
      'readAt': DateTime.now().toIso8601String(),
    });
  }
}
