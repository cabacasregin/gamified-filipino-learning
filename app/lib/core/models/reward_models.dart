import 'package:equatable/equatable.dart';

enum RedemptionStatus { pending, approved, fulfilled, rejected }

RedemptionStatus redemptionStatusFromString(String value) {
  return RedemptionStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => RedemptionStatus.pending,
  );
}

/// Mirrors `rewards`, defined by a parent for one of their children.
class Reward extends Equatable {
  final String id;
  final String parentId;
  final String studentId;
  final String name;
  final String description;
  final String emoji;
  final int pointCost;
  final bool active;

  const Reward({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.name,
    required this.description,
    required this.emoji,
    required this.pointCost,
    required this.active,
  });

  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      studentId: map['student_id'] as String,
      name: map['name'] as String,
      description: (map['description'] as String?) ?? '',
      // The `rewards` table's column is named `icon` (matching lesson_items'
      // `emoji` column's sibling naming elsewhere isn't consistent — this
      // is just what the schema calls it); kept as `emoji` on the Dart side
      // since that's clearer for a value that's always an emoji string.
      emoji: (map['icon'] as String?) ?? '🎁',
      pointCost: map['point_cost'] as int,
      active: (map['active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'student_id': studentId,
        'name': name,
        'description': description,
        'emoji': emoji,
        'point_cost': pointCost,
        'active': active,
      };

  /// Translates an app-facing field map (as produced by [toMap] / the
  /// rewards UI, which uses `emoji`) into real `rewards` column names
  /// (`icon`). Only translates keys that are present, so it's safe to use
  /// for partial `update()` payloads too.
  static Map<String, dynamic> mapToColumns(Map<String, dynamic> appFields) {
    final columns = Map<String, dynamic>.from(appFields);
    if (columns.containsKey('emoji')) {
      columns['icon'] = columns.remove('emoji');
    }
    return columns;
  }

  @override
  List<Object?> get props =>
      [id, parentId, studentId, name, description, emoji, pointCost, active];
}

/// Mirrors `reward_redemptions`.
class RewardRedemption extends Equatable {
  final String id;
  final String rewardId;
  final String studentId;
  final RedemptionStatus status;
  final int pointsSpent;
  final DateTime requestedAt;

  const RewardRedemption({
    required this.id,
    required this.rewardId,
    required this.studentId,
    required this.status,
    required this.pointsSpent,
    required this.requestedAt,
  });

  factory RewardRedemption.fromMap(Map<String, dynamic> map) {
    return RewardRedemption(
      id: map['id'] as String,
      rewardId: map['reward_id'] as String,
      studentId: map['student_id'] as String,
      status: redemptionStatusFromString(map['status'] as String),
      pointsSpent: map['points_spent'] as int,
      requestedAt: DateTime.parse(map['requested_at'] as String),
    );
  }

  @override
  List<Object?> get props => [id, rewardId, studentId, status, pointsSpent, requestedAt];
}
