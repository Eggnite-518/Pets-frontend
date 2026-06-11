class CaretakerReviewPage {
  final int total;
  final int page;
  final int pageSize;
  final List<CaretakerReviewItem> list;

  const CaretakerReviewPage({
    required this.total,
    required this.page,
    required this.pageSize,
    required this.list,
  });

  factory CaretakerReviewPage.fromJson(Map<String, dynamic> json) {
    final items = json['list'] as List? ?? [];
    return CaretakerReviewPage(
      total: _toInt(json['total']),
      page: _toInt(json['page'], fallback: 1),
      pageSize: _toInt(json['pageSize'], fallback: 10),
      list: items
          .whereType<Map>()
          .map(
            (e) => CaretakerReviewItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
    );
  }
}

class CaretakerReviewStats {
  final int reviewCount;
  final double overallAvg;
  final double punctualityAvg;
  final double professionalAvg;
  final int lowScoreCount;
  final double lowScoreRate;
  final int recent30DayReviewCount;
  final int recent30DayLowScoreCount;

  const CaretakerReviewStats({
    required this.reviewCount,
    required this.overallAvg,
    required this.punctualityAvg,
    required this.professionalAvg,
    required this.lowScoreCount,
    required this.lowScoreRate,
    required this.recent30DayReviewCount,
    required this.recent30DayLowScoreCount,
  });

  factory CaretakerReviewStats.fromJson(Map<String, dynamic> json) {
    return CaretakerReviewStats(
      reviewCount: _toInt(json['reviewCount']),
      overallAvg: _toDouble(json['overallAvg']),
      punctualityAvg: _toDouble(json['punctualityAvg']),
      professionalAvg: _toDouble(json['professionalAvg']),
      lowScoreCount: _toInt(json['lowScoreCount']),
      lowScoreRate: _toDouble(json['lowScoreRate']),
      recent30DayReviewCount: _toInt(json['recent30DayReviewCount']),
      recent30DayLowScoreCount: _toInt(json['recent30DayLowScoreCount']),
    );
  }
}

class CaretakerReviewItem {
  final int reviewId;
  final int orderId;
  final String serviceDate;
  final List<ReviewPetBrief> pets;
  final int overallScore;
  final int punctualityScore;
  final int professionalScore;
  final String comment;
  final List<ReviewDeductionReason> deductionReasons;
  final int creditDeductionScore;
  final List<ReviewAttachment> attachments;
  final int reviewStatus;
  final String reviewStatusDesc;
  final bool canAppeal;
  final String appealUnavailableReason;
  final String appealDeadline;
  final String createdAt;

  const CaretakerReviewItem({
    required this.reviewId,
    required this.orderId,
    required this.serviceDate,
    required this.pets,
    required this.overallScore,
    required this.punctualityScore,
    required this.professionalScore,
    required this.comment,
    required this.deductionReasons,
    required this.creditDeductionScore,
    required this.attachments,
    required this.reviewStatus,
    required this.reviewStatusDesc,
    required this.canAppeal,
    required this.appealUnavailableReason,
    required this.appealDeadline,
    required this.createdAt,
  });

  bool get isLowScore =>
      overallScore <= 3 || punctualityScore <= 3 || professionalScore <= 3;

  factory CaretakerReviewItem.fromJson(Map<String, dynamic> json) {
    final petsRaw = json['pets'] as List? ?? [];
    final reasonsRaw = json['deductionReasons'] as List? ?? [];
    final attachmentsRaw = json['attachments'] as List? ?? [];
    return CaretakerReviewItem(
      reviewId: _toInt(json['reviewId']),
      orderId: _toInt(json['orderId']),
      serviceDate: json['serviceDate']?.toString() ?? '',
      pets: petsRaw
          .whereType<Map>()
          .map((e) => ReviewPetBrief.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      overallScore: _toInt(json['overallScore']),
      punctualityScore: _toInt(json['punctualityScore']),
      professionalScore: _toInt(json['professionalScore']),
      comment: json['comment']?.toString() ?? '',
      deductionReasons: reasonsRaw
          .whereType<Map>()
          .map(
            (e) => ReviewDeductionReason.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList(),
      creditDeductionScore: _toInt(json['creditDeductionScore']),
      attachments: attachmentsRaw
          .whereType<Map>()
          .map((e) => ReviewAttachment.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      reviewStatus: _toInt(json['reviewStatus'], fallback: 1),
      reviewStatusDesc: json['reviewStatusDesc']?.toString() ?? '',
      canAppeal: json['canAppeal'] == true,
      appealUnavailableReason:
          json['appealUnavailableReason']?.toString() ?? '',
      appealDeadline: json['appealDeadline']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class ReviewPetBrief {
  final String petName;
  final int petType;
  final String petTypeDesc;

  const ReviewPetBrief({
    required this.petName,
    required this.petType,
    required this.petTypeDesc,
  });

  factory ReviewPetBrief.fromJson(Map<String, dynamic> json) {
    return ReviewPetBrief(
      petName: json['petName']?.toString() ?? '',
      petType: _toInt(json['petType']),
      petTypeDesc: json['petTypeDesc']?.toString() ?? '',
    );
  }
}

class ReviewDeductionReason {
  final int reasonType;
  final String reasonTypeDesc;
  final String reasonText;

  const ReviewDeductionReason({
    required this.reasonType,
    required this.reasonTypeDesc,
    required this.reasonText,
  });

  factory ReviewDeductionReason.fromJson(Map<String, dynamic> json) {
    return ReviewDeductionReason(
      reasonType: _toInt(json['reasonType']),
      reasonTypeDesc: json['reasonTypeDesc']?.toString() ?? '',
      reasonText: json['reasonText']?.toString() ?? '',
    );
  }
}

class ReviewAttachment {
  final int attachmentId;
  final String url;
  final String mediaType;

  const ReviewAttachment({
    required this.attachmentId,
    required this.url,
    required this.mediaType,
  });

  factory ReviewAttachment.fromJson(Map<String, dynamic> json) {
    return ReviewAttachment(
      attachmentId: _toInt(json['attachmentId']),
      url: json['url']?.toString() ?? '',
      mediaType: json['mediaType']?.toString() ?? '',
    );
  }

  bool get isVideo =>
      mediaType.toUpperCase() == 'VIDEO' ||
      url.toLowerCase().contains('.mp4') ||
      url.toLowerCase().contains('.mov');
}

class ReviewAppealEligibility {
  final int reviewId;
  final bool canAppeal;
  final String unavailableReason;
  final String appealDeadline;

  const ReviewAppealEligibility({
    required this.reviewId,
    required this.canAppeal,
    required this.unavailableReason,
    required this.appealDeadline,
  });

  factory ReviewAppealEligibility.fromJson(Map<String, dynamic> json) {
    return ReviewAppealEligibility(
      reviewId: _toInt(json['reviewId']),
      canAppeal: json['canAppeal'] == true,
      unavailableReason: json['unavailableReason']?.toString() ?? '',
      appealDeadline: json['appealDeadline']?.toString() ?? '',
    );
  }
}

class SubmitReviewAppealResult {
  final int appealId;
  final int appealStatus;
  final String appealStatusDesc;

  const SubmitReviewAppealResult({
    required this.appealId,
    required this.appealStatus,
    required this.appealStatusDesc,
  });

  factory SubmitReviewAppealResult.fromJson(Map<String, dynamic> json) {
    return SubmitReviewAppealResult(
      appealId: _toInt(json['appealId']),
      appealStatus: _toInt(json['appealStatus']),
      appealStatusDesc: json['appealStatusDesc']?.toString() ?? '',
    );
  }
}

class ReviewAppealDetail {
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

  const ReviewAppealDetail({
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

  bool get isTerminal => appealStatus == 4 || appealStatus == 5;

  factory ReviewAppealDetail.fromJson(Map<String, dynamic> json) {
    return ReviewAppealDetail(
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

int _toInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _toDouble(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _toStringList(Object? value) {
  if (value is List) {
    return value
        .map((item) => item?.toString() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return const [];
  return raw
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}
