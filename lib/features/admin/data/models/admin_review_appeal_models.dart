class AdminReviewAppealPage {
  final int total;
  final int page;
  final int pageSize;
  final List<AdminReviewAppealItem> list;

  const AdminReviewAppealPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  factory AdminReviewAppealPage.fromJson(Map<String, dynamic> json) {
    final items = json['list'] as List? ?? [];
    return AdminReviewAppealPage(
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      pageSize: _toInt(json['pageSize'], fallback: 10),
      list: items
          .whereType<Map>()
          .map((item) => AdminReviewAppealItem.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class AdminReviewAppealItem {
  final int appealId;
  final int reviewId;
  final int orderId;
  final int providerId;
  final int ownerId;
  final String reason;
  final List<String> evidenceUrls;
  final int appealStatus;
  final String appealStatusDesc;
  final String adminMemo;
  final String appealDeadline;
  final String closedAt;
  final String createdAt;

  const AdminReviewAppealItem({
    required this.appealId,
    required this.reviewId,
    required this.orderId,
    required this.providerId,
    required this.ownerId,
    required this.reason,
    required this.evidenceUrls,
    required this.appealStatus,
    required this.appealStatusDesc,
    required this.adminMemo,
    required this.appealDeadline,
    required this.closedAt,
    required this.createdAt,
  });

  bool get isClosed => appealStatus == 4 || appealStatus == 5;

  factory AdminReviewAppealItem.fromJson(Map<String, dynamic> json) {
    return AdminReviewAppealItem(
      appealId: _toInt(json['appealId']),
      reviewId: _toInt(json['reviewId']),
      orderId: _toInt(json['orderId']),
      providerId: _toInt(json['providerId']),
      ownerId: _toInt(json['ownerId']),
      reason: json['reason']?.toString() ?? '',
      evidenceUrls: _toStringList(json['evidenceUrls']),
      appealStatus: _toInt(json['appealStatus']),
      appealStatusDesc: json['appealStatusDesc']?.toString() ?? '',
      adminMemo: json['adminMemo']?.toString() ?? '',
      appealDeadline: json['appealDeadline']?.toString() ?? '',
      closedAt: json['closedAt']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class AdminOrderEvidenceChain {
  final AdminEvidenceOrderMeta? order;
  final List<AdminFulfillmentRecord> fulfillmentRecords;
  final List<AdminOfficialMessage> officialMessages;

  const AdminOrderEvidenceChain({
    required this.order,
    required this.fulfillmentRecords,
    required this.officialMessages,
  });

  factory AdminOrderEvidenceChain.fromJson(Map<String, dynamic> json) {
    final fulfillment = json['fulfillmentRecords'] as List? ?? [];
    final messages = json['officialMessages'] as List? ?? [];
    return AdminOrderEvidenceChain(
      order: json['order'] is Map
          ? AdminEvidenceOrderMeta.fromJson(
              Map<String, dynamic>.from(json['order'] as Map),
            )
          : null,
      fulfillmentRecords: fulfillment
          .whereType<Map>()
          .map((item) => AdminFulfillmentRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      officialMessages: messages
          .whereType<Map>()
          .map((item) => AdminOfficialMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class AdminEvidenceOrderMeta {
  final int orderId;
  final int ownerId;
  final int providerId;
  final int status;
  final String statusDesc;

  const AdminEvidenceOrderMeta({
    required this.orderId,
    required this.ownerId,
    required this.providerId,
    required this.status,
    required this.statusDesc,
  });

  factory AdminEvidenceOrderMeta.fromJson(Map<String, dynamic> json) {
    return AdminEvidenceOrderMeta(
      orderId: _toInt(json['orderId']),
      ownerId: _toInt(json['ownerId']),
      providerId: _toInt(json['providerId']),
      status: _toInt(json['status']),
      statusDesc: json['statusDesc']?.toString() ?? '',
    );
  }
}

class AdminFulfillmentRecord {
  final int nodeType;
  final String nodeTypeDesc;
  final String url;
  final String mediaType;
  final String objectKey;
  final int fileSize;
  final String contentType;
  final int frameRate;
  final int processingStatus;
  final String processingErrorCode;
  final String processingError;
  final String watermarkText;
  final String createdAt;

  const AdminFulfillmentRecord({
    required this.nodeType,
    required this.nodeTypeDesc,
    required this.url,
    required this.mediaType,
    required this.objectKey,
    required this.fileSize,
    required this.contentType,
    required this.frameRate,
    required this.processingStatus,
    required this.processingErrorCode,
    required this.processingError,
    required this.watermarkText,
    required this.createdAt,
  });

  bool get hasMedia => url.isNotEmpty;
  bool get isVideo =>
      mediaType.toUpperCase() == 'VIDEO' ||
      url.toLowerCase().contains('.mp4') ||
      url.toLowerCase().contains('.mov');

  factory AdminFulfillmentRecord.fromJson(Map<String, dynamic> json) {
    return AdminFulfillmentRecord(
      nodeType: _toInt(json['nodeType']),
      nodeTypeDesc: json['nodeTypeDesc']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? '',
      objectKey: json['objectKey']?.toString() ?? '',
      fileSize: _toInt(json['fileSize']),
      contentType: json['contentType']?.toString() ?? '',
      frameRate: _toInt(json['frameRate']),
      processingStatus: _toInt(json['processingStatus']),
      processingErrorCode: json['processingErrorCode']?.toString() ?? '',
      processingError: json['processingError']?.toString() ?? '',
      watermarkText: json['watermarkText']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class AdminOfficialMessage {
  final int messageId;
  final int orderId;
  final int senderId;
  final int receiverId;
  final String content;
  final String createdAt;

  const AdminOfficialMessage({
    required this.messageId,
    required this.orderId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.createdAt,
  });

  factory AdminOfficialMessage.fromJson(Map<String, dynamic> json) {
    return AdminOfficialMessage(
      messageId: _toInt(json['messageId']),
      orderId: _toInt(json['orderId']),
      senderId: _toInt(json['senderId']),
      receiverId: _toInt(json['receiverId']),
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

int _toInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _toStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
