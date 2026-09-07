import 'package:equatable/equatable.dart';

enum PointsSourceType { learn, assessment, rewardRedeem }

PointsSourceType pointsSourceFromString(String value) {
  switch (value) {
    case 'assessment':
      return PointsSourceType.assessment;
    case 'reward_redeem':
      return PointsSourceType.rewardRedeem;
    default:
      return PointsSourceType.learn;
  }
}

/// Mirrors `points_transactions`. Never inserted directly by the client —
/// always the result of an RPC call (see `PointsRepository`).
class PointsTransaction extends Equatable {
  final String id;
  final String studentId;
  final PointsSourceType sourceType;
  final String? sourceId;
  final int points;
  final String? note;
  final DateTime createdAt;

  const PointsTransaction({
    required this.id,
    required this.studentId,
    required this.sourceType,
    this.sourceId,
    required this.points,
    this.note,
    required this.createdAt,
  });

  factory PointsTransaction.fromMap(Map<String, dynamic> map) {
    return PointsTransaction(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      sourceType: pointsSourceFromString(map['source_type'] as String),
      sourceId: map['source_id'] as String?,
      points: map['delta'] as int, // column is named `delta` in points_transactions
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, studentId, sourceType, sourceId, points, note, createdAt];
}

/// Server-verified outcome of one `record_assessment_attempt` RPC call —
/// see `PointsRepository.recordAssessmentAttempt` for why callers must
/// branch UI feedback on this rather than their own local guess.
class AssessmentResult extends Equatable {
  final bool isCorrect;
  final int pointsAwarded;

  const AssessmentResult({required this.isCorrect, required this.pointsAwarded});

  @override
  List<Object?> get props => [isCorrect, pointsAwarded];
}

/// Mirrors `assessment_attempts`.
class AssessmentAttempt extends Equatable {
  final String id;
  final String studentId;
  final String lessonItemId;
  final String transcript;
  final bool isCorrect;
  final int pointsAwarded;
  final DateTime attemptedAt;

  const AssessmentAttempt({
    required this.id,
    required this.studentId,
    required this.lessonItemId,
    required this.transcript,
    required this.isCorrect,
    required this.pointsAwarded,
    required this.attemptedAt,
  });

  factory AssessmentAttempt.fromMap(Map<String, dynamic> map) {
    return AssessmentAttempt(
      id: map['id'] as String,
      studentId: map['student_id'] as String,
      lessonItemId: map['lesson_item_id'] as String,
      transcript: (map['transcript'] as String?) ?? '',
      isCorrect: map['is_correct'] as bool,
      pointsAwarded: (map['points_awarded'] as int?) ?? 0,
      attemptedAt: DateTime.parse(map['attempted_at'] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    studentId,
    lessonItemId,
    transcript,
    isCorrect,
    pointsAwarded,
    attemptedAt,
  ];
}

/// Mirrors `learn_completions`.
class LearnCompletion extends Equatable {
  final String studentId;
  final String lessonItemId;
  final DateTime completedAt;

  const LearnCompletion({
    required this.studentId,
    required this.lessonItemId,
    required this.completedAt,
  });

  factory LearnCompletion.fromMap(Map<String, dynamic> map) {
    return LearnCompletion(
      studentId: map['student_id'] as String,
      lessonItemId: map['lesson_item_id'] as String,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  @override
  List<Object?> get props => [studentId, lessonItemId, completedAt];
}
