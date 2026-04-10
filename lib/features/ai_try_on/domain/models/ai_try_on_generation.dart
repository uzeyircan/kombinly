class AiTryOnGeneration {
  final String id;
  final String userId;
  final String mannequinImageUrl;
  final String garmentImageUrl;
  final String? resultImageUrl;
  final String prompt;
  final String status;
  final String? errorMessage;
  final String? sourceClothingId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiTryOnGeneration({
    required this.id,
    required this.userId,
    required this.mannequinImageUrl,
    required this.garmentImageUrl,
    required this.resultImageUrl,
    required this.prompt,
    required this.status,
    required this.errorMessage,
    required this.sourceClothingId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isQueued => status == 'queued';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  factory AiTryOnGeneration.fromMap(Map<String, dynamic> map) {
    return AiTryOnGeneration(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      mannequinImageUrl: map['mannequin_image_url'] as String,
      garmentImageUrl: map['garment_image_url'] as String,
      resultImageUrl: map['result_image_url'] as String?,
      prompt: map['prompt'] as String,
      status: map['status'] as String,
      errorMessage: map['error_message'] as String?,
      sourceClothingId: map['source_clothing_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
