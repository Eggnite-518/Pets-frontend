class OrderRatingDetailModel {
  final String reviewId;
  final String orderId;
  final int overallScore;
  final int punctualityScore;
  final int professionalScore;
  final String comment;
  final List<OrderRatingReasonModel> deductionReasons;
  final List<OrderRatingAttachmentModel> attachments;
  final int reviewStatus;
  final String reviewStatusDesc;
  final bool canAppeal;
  final String appealDeadline;
  final String createdAt;

  const OrderRatingDetailModel({
    required this.reviewId,
    required this.orderId,
    required this.overallScore,
    required this.punctualityScore,
    required this.professionalScore,
    required this.comment,
    required this.deductionReasons,
    required this.attachments,
    required this.reviewStatus,
    required this.reviewStatusDesc,
    required this.canAppeal,
    required this.appealDeadline,
    required this.createdAt,
  });

  factory OrderRatingDetailModel.fromJson(Map<String, dynamic> json) {
    return OrderRatingDetailModel(
      reviewId: json['reviewId']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      overallScore: _toInt(json['overallScore']),
      punctualityScore: _toInt(json['punctualityScore']),
      professionalScore: _toInt(json['professionalScore']),
      comment: json['comment']?.toString() ?? '',
      deductionReasons: _parseList(
        json['deductionReasons'],
        OrderRatingReasonModel.fromJson,
      ),
      attachments: _parseList(
        json['attachments'],
        OrderRatingAttachmentModel.fromJson,
      ),
      reviewStatus: _toInt(json['reviewStatus']),
      reviewStatusDesc: json['reviewStatusDesc']?.toString() ?? '',
      canAppeal: json['canAppeal'] == true,
      appealDeadline: json['appealDeadline']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }

  static int _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<T> _parseList<T>(
    Object? value,
    T Function(Map<String, dynamic>) parser,
  ) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => parser(Map<String, dynamic>.from(item)))
        .toList();
  }
}

class OrderRatingReasonModel {
  final int reasonType;
  final String reasonTypeDesc;
  final String reasonText;

  const OrderRatingReasonModel({
    required this.reasonType,
    required this.reasonTypeDesc,
    required this.reasonText,
  });

  factory OrderRatingReasonModel.fromJson(Map<String, dynamic> json) {
    return OrderRatingReasonModel(
      reasonType: OrderRatingDetailModel._toInt(json['reasonType']),
      reasonTypeDesc: json['reasonTypeDesc']?.toString() ?? '',
      reasonText: json['reasonText']?.toString() ?? '',
    );
  }
}

class OrderRatingAttachmentModel {
  final String url;
  final String objectKey;
  final String mediaType;
  final String contentType;
  final int fileSize;
  final int sortOrder;

  const OrderRatingAttachmentModel({
    required this.url,
    required this.objectKey,
    required this.mediaType,
    required this.contentType,
    required this.fileSize,
    required this.sortOrder,
  });

  factory OrderRatingAttachmentModel.fromJson(Map<String, dynamic> json) {
    return OrderRatingAttachmentModel(
      url: json['url']?.toString() ?? '',
      objectKey: json['objectKey']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      fileSize: OrderRatingDetailModel._toInt(json['fileSize']),
      sortOrder: OrderRatingDetailModel._toInt(json['sortOrder']),
    );
  }
}
