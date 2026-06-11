import 'package:pets/core/utils/image_url_helper.dart';

class OrderDisputeItem {
  final int disputeId;
  final int orderId;
  final int plaintiffId;
  final int defendantId;
  final int disputeType;
  final String disputeTypeDesc;
  final String reason;
  final List<String> evidenceUrls;
  final int disputeStatus;
  final String disputeStatusDesc;
  final int resultType;
  final String resultTypeDesc;
  final String adminMemo;
  final String createdAt;
  final String closedAt;

  const OrderDisputeItem({
    required this.disputeId,
    required this.orderId,
    required this.plaintiffId,
    required this.defendantId,
    required this.disputeType,
    required this.disputeTypeDesc,
    required this.reason,
    required this.evidenceUrls,
    required this.disputeStatus,
    required this.disputeStatusDesc,
    required this.resultType,
    required this.resultTypeDesc,
    required this.adminMemo,
    required this.createdAt,
    required this.closedAt,
  });

  bool get isClosed => closedAt.isNotEmpty;

  factory OrderDisputeItem.fromJson(Map<String, dynamic> json) {
    return OrderDisputeItem(
      disputeId: _toInt(json['disputeId']),
      orderId: _toInt(json['orderId']),
      plaintiffId: _toInt(json['plaintiffId']),
      defendantId: _toInt(json['defendantId']),
      disputeType: _toInt(json['disputeType']),
      disputeTypeDesc: json['disputeTypeDesc']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      evidenceUrls: _toStringList(json['evidenceUrls']),
      disputeStatus: _toInt(json['disputeStatus']),
      disputeStatusDesc: json['disputeStatusDesc']?.toString() ?? '',
      resultType: _toInt(json['resultType']),
      resultTypeDesc: json['resultTypeDesc']?.toString() ?? '',
      adminMemo: json['adminMemo']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
      closedAt: json['closedAt']?.toString() ?? '',
    );
  }
}

class SubmitOrderDisputeResult {
  final int disputeId;
  final int disputeStatus;

  const SubmitOrderDisputeResult({
    required this.disputeId,
    required this.disputeStatus,
  });

  factory SubmitOrderDisputeResult.fromJson(Map<String, dynamic> json) {
    return SubmitOrderDisputeResult(
      disputeId: _toInt(json['disputeId']),
      disputeStatus: _toInt(json['disputeStatus']),
    );
  }
}

class OrderEvidenceChain {
  final OrderEvidenceMeta? order;
  final List<OrderFulfillmentRecord> fulfillmentRecords;
  final List<OrderOfficialMessage> officialMessages;

  const OrderEvidenceChain({
    required this.order,
    required this.fulfillmentRecords,
    required this.officialMessages,
  });

  factory OrderEvidenceChain.fromJson(Map<String, dynamic> json) {
    final fulfillment = json['fulfillmentRecords'] as List? ?? [];
    final messages = json['officialMessages'] as List? ?? [];
    return OrderEvidenceChain(
      order: json['order'] is Map
          ? OrderEvidenceMeta.fromJson(Map<String, dynamic>.from(json['order'] as Map))
          : null,
      fulfillmentRecords: fulfillment
          .whereType<Map>()
          .map((item) => OrderFulfillmentRecord.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      officialMessages: messages
          .whereType<Map>()
          .map((item) => OrderOfficialMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

class OrderEvidenceMeta {
  final int orderId;
  final int ownerId;
  final int providerId;
  final int status;
  final String statusDesc;

  const OrderEvidenceMeta({
    required this.orderId,
    required this.ownerId,
    required this.providerId,
    required this.status,
    required this.statusDesc,
  });

  factory OrderEvidenceMeta.fromJson(Map<String, dynamic> json) {
    return OrderEvidenceMeta(
      orderId: _toInt(json['orderId']),
      ownerId: _toInt(json['ownerId']),
      providerId: _toInt(json['providerId']),
      status: _toInt(json['status']),
      statusDesc: json['statusDesc']?.toString() ?? '',
    );
  }
}

class OrderFulfillmentRecord {
  final int nodeType;
  final String nodeTypeDesc;
  final String url;
  final String mediaType;
  final String watermarkText;
  final String createdAt;

  const OrderFulfillmentRecord({
    required this.nodeType,
    required this.nodeTypeDesc,
    required this.url,
    required this.mediaType,
    required this.watermarkText,
    required this.createdAt,
  });

  bool get hasMedia => url.isNotEmpty;
  bool get isVideo =>
      mediaType.toUpperCase() == 'VIDEO' ||
      url.toLowerCase().contains('.mp4') ||
      url.toLowerCase().contains('.mov');

  factory OrderFulfillmentRecord.fromJson(Map<String, dynamic> json) {
    return OrderFulfillmentRecord(
      nodeType: _toInt(json['nodeType']),
      nodeTypeDesc: json['nodeTypeDesc']?.toString() ?? '',
      url: ensureHttpsMediaUrl(
        json['imageUrl']?.toString() ?? json['url']?.toString(),
      ),
      mediaType: json['mediaType']?.toString() ?? '',
      watermarkText: json['watermarkText']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class OrderOfficialMessage {
  final int messageId;
  final String content;
  final String createdAt;

  const OrderOfficialMessage({
    required this.messageId,
    required this.content,
    required this.createdAt,
  });

  factory OrderOfficialMessage.fromJson(Map<String, dynamic> json) {
    return OrderOfficialMessage(
      messageId: _toInt(json['messageId']),
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
