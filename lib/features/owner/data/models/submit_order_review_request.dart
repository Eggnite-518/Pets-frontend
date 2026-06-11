import 'review_attachment_model.dart';

class ReviewDeductionReasonRequest {
  final int reasonType;
  final String? reasonText;

  const ReviewDeductionReasonRequest({
    required this.reasonType,
    this.reasonText,
  });

  Map<String, dynamic> toJson() {
    return {'reasonType': reasonType, 'reasonText': reasonText};
  }
}

class SubmitOrderReviewRequest {
  final int overallScore;
  final int punctualityScore;
  final int professionalScore;
  final String comment;
  final List<ReviewDeductionReasonRequest> deductionReasons;
  final List<ReviewAttachmentModel> attachments;

  const SubmitOrderReviewRequest({
    required this.overallScore,
    required this.punctualityScore,
    required this.professionalScore,
    required this.comment,
    this.deductionReasons = const [],
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'overallScore': overallScore,
      'punctualityScore': punctualityScore,
      'professionalScore': professionalScore,
      'comment': comment,
      if (deductionReasons.isNotEmpty)
        'deductionReasons': deductionReasons
            .map((reason) => reason.toJson())
            .toList(),
      if (attachments.isNotEmpty)
        'attachments': attachments
            .asMap()
            .entries
            .map((entry) => entry.value.withSortOrder(entry.key + 1).toJson())
            .toList(),
    };
  }
}
