import 'vm_communication_models.dart';

class VmNotificationPayloadFactory {
  const VmNotificationPayloadFactory._();

  static VmNotificationPayload chatMessage({
    required String id,
    required String conversationId,
    required String messageId,
    required String title,
    required String body,
    int? senderPublicUserId,
  }) {
    return VmNotificationPayload(
      id: id,
      type: VmNotificationPayloadType.message,
      title: title,
      body: body,
      conversationId: conversationId,
      messageId: messageId,
      senderPublicUserId: senderPublicUserId,
    );
  }

  static VmNotificationPayload roomInvite({
    required String id,
    required String conversationId,
    required String messageId,
    required String roomPublicId,
    required String title,
    required String body,
    int? senderPublicUserId,
  }) {
    return VmNotificationPayload(
      id: id,
      type: VmNotificationPayloadType.roomInvite,
      title: title,
      body: body,
      conversationId: conversationId,
      messageId: messageId,
      roomPublicId: roomPublicId,
      senderPublicUserId: senderPublicUserId,
    );
  }

  static VmNotificationPayload teamSystem({
    required String id,
    required String conversationId,
    required String messageId,
    required String title,
    required String body,
  }) {
    return VmNotificationPayload(
      id: id,
      type: VmNotificationPayloadType.teamSystem,
      title: title,
      body: body,
      conversationId: conversationId,
      messageId: messageId,
    );
  }

  static VmNotificationPayload strangerRequest({
    required String id,
    required String conversationId,
    required String messageId,
    required String title,
    required String body,
    int? senderPublicUserId,
  }) {
    return VmNotificationPayload(
      id: id,
      type: VmNotificationPayloadType.strangerRequest,
      title: title,
      body: body,
      conversationId: conversationId,
      messageId: messageId,
      senderPublicUserId: senderPublicUserId,
    );
  }

  static VmNotificationPayload callInvite({
    required String id,
    required String callId,
    required String title,
    required String body,
    String? conversationId,
    int? senderPublicUserId,
  }) {
    return VmNotificationPayload(
      id: id,
      type: VmNotificationPayloadType.call,
      title: title,
      body: body,
      conversationId: conversationId,
      callId: callId,
      senderPublicUserId: senderPublicUserId,
    );
  }

  static VmQuickReplyPayload buildQuickReply({
    required String notificationId,
    required String conversationId,
    required String replyText,
    String? messageId,
  }) {
    return VmQuickReplyPayload(
      notificationId: notificationId,
      conversationId: conversationId,
      messageId: messageId,
      replyText: replyText,
    );
  }
}
