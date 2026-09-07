import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reward_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';

final _studentRewardsProvider = FutureProvider.family<List<Reward>, String>((ref, studentId) {
  return ref.watch(rewardsRepositoryProvider).fetchRewardsForStudent(studentId);
});

final _studentRedemptionsProvider = FutureProvider.family<List<RewardRedemption>, String>((
  ref,
  studentId,
) {
  return ref.watch(rewardsRepositoryProvider).fetchRedemptionsForStudent(studentId);
});

/// Student-facing points wallet: current balance, a catalog of the
/// rewards their parent has set up (redeemable while the balance lasts),
/// and a simple history of past redemption requests.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final studentId = profile.id;
    final balanceAsync = ref.watch(pointsBalanceProvider(studentId));
    final rewardsAsync = ref.watch(_studentRewardsProvider(studentId));
    final redemptionsAsync = ref.watch(_studentRedemptionsProvider(studentId));

    Future<void> refresh() async {
      ref.invalidate(_studentRewardsProvider(studentId));
      ref.invalidate(_studentRedemptionsProvider(studentId));
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _WalletHeader(balance: balanceAsync.valueOrNull ?? 0),
          const SizedBox(height: 24),
          Text(
            'Mga Gantimpala',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AsyncView<List<Reward>>(
            value: rewardsAsync,
            emptyMessage: 'Wala pang gantimpalang na-set up ang magulang mo. Balik ka mamaya!',
            isEmpty: (data) => data.isEmpty,
            builder: (rewards) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: rewards.length,
              itemBuilder: (context, i) => _RewardCard(
                reward: rewards[i],
                balance: balanceAsync.valueOrNull ?? 0,
                onRedeemed: refresh,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Kasaysayan ng Redemptions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AsyncView<List<RewardRedemption>>(
            value: redemptionsAsync,
            emptyMessage: 'Wala ka pang na-redeem na gantimpala.',
            isEmpty: (data) => data.isEmpty,
            builder: (redemptions) => Column(
              children: [for (final r in redemptions.reversed) _RedemptionTile(redemption: r)],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletHeader extends StatelessWidget {
  final int balance;
  const _WalletHeader({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.points.withValues(alpha: 0.9),
            AppColors.secondary.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            '$balance points',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 4),
          const Text('Iyong balanse ngayon', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _RewardCard extends ConsumerStatefulWidget {
  final Reward reward;
  final int balance;
  final Future<void> Function() onRedeemed;

  const _RewardCard({required this.reward, required this.balance, required this.onRedeemed});

  @override
  ConsumerState<_RewardCard> createState() => _RewardCardState();
}

class _RewardCardState extends ConsumerState<_RewardCard> {
  bool _redeeming = false;

  Future<void> _confirmAndRedeem() async {
    final reward = widget.reward;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('I-redeem ang gantimpala?'),
        content: Text('I-redeem ang "${reward.name}" para sa ${reward.pointCost} points?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Kanselahin'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I-redeem'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _redeeming = true);
    try {
      await ref.read(rewardsRepositoryProvider).requestRedemption(reward.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Naipadala ang kahilingan para sa "${reward.name}"! Hintayin ang approval ng magulang mo.',
          ),
        ),
      );
      await widget.onRedeemed();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hindi na-redeem: $e')));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    final canAfford = widget.balance >= reward.pointCost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(reward.emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              reward.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (reward.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                reward.description,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⭐ ', style: TextStyle(fontSize: 14)),
                Text('${reward.pointCost}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (canAfford && !_redeeming) ? _confirmAndRedeem : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                child: _redeeming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(canAfford ? 'I-redeem' : 'Kulang ang points'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedemptionTile extends StatelessWidget {
  final RewardRedemption redemption;
  const _RedemptionTile({required this.redemption});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (redemption.status) {
      RedemptionStatus.pending => ('Naghihintay', Colors.orange),
      RedemptionStatus.approved => ('Aprubado', AppColors.primary),
      RedemptionStatus.fulfilled => ('Naibigay na', AppColors.success),
      RedemptionStatus.rejected => ('Tinanggihan', AppColors.error),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Text('🎁', style: TextStyle(fontSize: 24)),
        title: Text('${redemption.pointsSpent} points'),
        subtitle: Text(_formatDate(redemption.requestedAt)),
        trailing: Chip(
          label: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
