import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reward_models.dart';
import 'supabase_service.dart';

class RewardsRepository {
  final SupabaseClient _client = SupabaseService.client;

  /// Active rewards only — what the student sees in their own catalog.
  Future<List<Reward>> fetchRewardsForStudent(String studentId) async {
    final rows = await _client
        .from('rewards')
        .select()
        .eq('student_id', studentId)
        .eq('active', true)
        .order('point_cost');
    return rows.map((r) => Reward.fromMap(r)).toList();
  }

  /// All of a child's rewards regardless of `active`, for the parent's
  /// management screen (they need to see and re-enable a deactivated
  /// reward, not just the ones currently visible to the student).
  Future<List<Reward>> fetchAllRewardsForStudent(String studentId) async {
    final rows = await _client
        .from('rewards')
        .select()
        .eq('student_id', studentId)
        .order('point_cost');
    return rows.map((r) => Reward.fromMap(r)).toList();
  }

  /// Parent-only (enforced by RLS: `parent_id` must be the caller and
  /// `student_id` must be one of their linked children).
  Future<Reward> createReward(Reward reward) async {
    final columns = Reward.mapToColumns({...reward.toMap(), 'parent_id': reward.parentId});
    final row = await _client.from('rewards').insert(columns).select().single();
    return Reward.fromMap(row);
  }

  /// [changes] uses the same app-facing keys as [Reward.toMap] (e.g. from
  /// the parent rewards UI), translated to real column names here.
  Future<void> updateReward(String id, Map<String, dynamic> changes) async {
    final columns = Reward.mapToColumns(changes);
    await _client.from('rewards').update(columns).eq('id', id);
  }

  Future<void> deleteReward(String id) async {
    await _client.from('rewards').delete().eq('id', id);
  }

  /// Student requests a redemption; points are deducted immediately by the
  /// `redeem_reward` RPC (refunded automatically if a parent rejects it).
  Future<String> requestRedemption(String rewardId) async {
    final result = await _client.rpc('redeem_reward', params: {'p_reward_id': rewardId});
    return result as String;
  }

  Future<List<RewardRedemption>> fetchRedemptionsForStudent(String studentId) async {
    final rows = await _client
        .from('reward_redemptions')
        .select()
        .eq('student_id', studentId)
        .order('requested_at');
    return rows.map((r) => RewardRedemption.fromMap(r)).toList();
  }

  /// Parent reviewing a pending redemption for one of their children.
  Future<void> setRedemptionStatus(String redemptionId, RedemptionStatus status) async {
    await _client
        .from('reward_redemptions')
        .update({'status': status.name}).eq('id', redemptionId);
  }
}
