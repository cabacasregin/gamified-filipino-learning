import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/reward_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';

final _parentChildrenProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(progressRepositoryProvider).fetchChildrenForParent();
});

final _childRewardsProvider = FutureProvider.family<List<Reward>, String>((ref, childId) {
  return ref.watch(rewardsRepositoryProvider).fetchAllRewardsForStudent(childId);
});

final _childRedemptionsProvider =
    FutureProvider.family<List<RewardRedemption>, String>((ref, childId) {
  return ref.watch(rewardsRepositoryProvider).fetchRedemptionsForStudent(childId);
});

/// Parent-facing reward management: pick a child (skipped when the parent
/// has only one), then create/edit/delete that child's redeemable rewards
/// and approve or reject their pending redemption requests.
class ParentRewardsScreen extends ConsumerStatefulWidget {
  const ParentRewardsScreen({super.key});

  @override
  ConsumerState<ParentRewardsScreen> createState() => _ParentRewardsScreenState();
}

class _ParentRewardsScreenState extends ConsumerState<ParentRewardsScreen> {
  String? _selectedChildId;

  void _refreshChild(String childId) {
    ref.invalidate(_childRewardsProvider(childId));
    ref.invalidate(_childRedemptionsProvider(childId));
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(_parentChildrenProvider);

    return AsyncView<List<Map<String, dynamic>>>(
      value: childrenAsync,
      emptyMessage: 'Wala ka pang naka-link na anak. Makipag-ugnayan sa paaralan para ma-link.',
      isEmpty: (data) => data.isEmpty,
      builder: (children) {
        // Single child: skip the picker entirely.
        final selectedId = children.length == 1 ? children.first['id'] as String : _selectedChildId;
        if (selectedId == null) {
          return _ChildPicker(
            children: children,
            onSelected: (id) => setState(() => _selectedChildId = id),
          );
        }
        final selectedChild = children.firstWhere(
          (c) => c['id'] == selectedId,
          orElse: () => children.first,
        );
        return _ChildRewardsManager(
          childId: selectedId,
          childName: (selectedChild['full_name'] as String?) ?? 'Anak',
          showBackToPicker: children.length > 1,
          onBack: () => setState(() => _selectedChildId = null),
          onChanged: () => _refreshChild(selectedId),
        );
      },
    );
  }
}

class _ChildPicker extends StatelessWidget {
  final List<Map<String, dynamic>> children;
  final ValueChanged<String> onSelected;
  const _ChildPicker({required this.children, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Piliin ang anak', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        for (final c in children)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text((c['full_name'] as String?) ?? 'Anak'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onSelected(c['id'] as String),
            ),
          ),
      ],
    );
  }
}

class _ChildRewardsManager extends ConsumerWidget {
  final String childId;
  final String childName;
  final bool showBackToPicker;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  const _ChildRewardsManager({
    required this.childId,
    required this.childName,
    required this.showBackToPicker,
    required this.onBack,
    required this.onChanged,
  });

  Future<void> _openRewardForm(BuildContext context, WidgetRef ref, {Reward? existing}) async {
    final result = await showDialog<_RewardFormResult>(
      context: context,
      builder: (context) => _RewardFormDialog(existing: existing),
    );
    if (result == null) return;

    final profile = ref.read(currentProfileProvider).valueOrNull;
    try {
      if (existing == null) {
        if (profile == null) return;
        await ref.read(rewardsRepositoryProvider).createReward(Reward(
              id: '',
              parentId: profile.id,
              studentId: childId,
              name: result.name,
              description: result.description,
              emoji: result.emoji,
              pointCost: result.pointCost,
              active: true,
            ));
      } else {
        await ref.read(rewardsRepositoryProvider).updateReward(existing.id, {
          'name': result.name,
          'description': result.description,
          'emoji': result.emoji,
          'point_cost': result.pointCost,
          'active': result.active,
        });
      }
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hindi na-save: $e')));
    }
  }

  Future<void> _deleteReward(BuildContext context, WidgetRef ref, Reward reward) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tanggalin ang gantimpala?'),
        content: Text('Tatanggalin ang "${reward.name}". Hindi na ito puwedeng i-undo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Kanselahin')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tanggalin'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(rewardsRepositoryProvider).deleteReward(reward.id);
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hindi na-tanggal: $e')));
    }
  }

  Future<void> _setRedemptionStatus(
    BuildContext context,
    WidgetRef ref,
    RewardRedemption redemption,
    RedemptionStatus status,
  ) async {
    try {
      await ref.read(rewardsRepositoryProvider).setRedemptionStatus(redemption.id, status);
      onChanged();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hindi na-update: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(_childRewardsProvider(childId));
    final redemptionsAsync = ref.watch(_childRedemptionsProvider(childId));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRewardForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Bagong Gantimpala'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              if (showBackToPicker)
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
              Expanded(
                child: Text(
                  'Mga gantimpala para kay $childName',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AsyncView<List<RewardRedemption>>(
            value: redemptionsAsync,
            builder: (redemptions) {
              final pending = redemptions.where((r) => r.status == RedemptionStatus.pending).toList();
              if (pending.isEmpty) return const SizedBox.shrink();
              return AsyncView<List<Reward>>(
                value: rewardsAsync,
                builder: (allRewards) {
                  final byId = {for (final r in allRewards) r.id: r};
                  return Card(
                    color: Colors.orange.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Naghihintay ng approval (${pending.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final r in pending)
                            _PendingRedemptionTile(
                              redemption: r,
                              rewardName: byId[r.rewardId]?.name,
                              rewardEmoji: byId[r.rewardId]?.emoji,
                              onApprove: () =>
                                  _setRedemptionStatus(context, ref, r, RedemptionStatus.approved),
                              onReject: () =>
                                  _setRedemptionStatus(context, ref, r, RedemptionStatus.rejected),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 20),
          Text('Listahan ng gantimpala', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AsyncView<List<Reward>>(
            value: rewardsAsync,
            emptyMessage: 'Wala ka pang nagawang gantimpala. Gumawa ng una gamit ang button sa ibaba.',
            isEmpty: (data) => data.isEmpty,
            builder: (rewards) => Column(
              children: [
                for (final reward in rewards)
                  Card(
                    child: ListTile(
                      leading: Text(reward.emoji, style: const TextStyle(fontSize: 28)),
                      title: Text(reward.name),
                      subtitle: Text(
                        reward.description.isNotEmpty
                            ? '${reward.description}\n${reward.pointCost} points'
                            : '${reward.pointCost} points',
                      ),
                      isThreeLine: reward.description.isNotEmpty,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _openRewardForm(context, ref, existing: reward),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => _deleteReward(context, ref, reward),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRedemptionTile extends StatelessWidget {
  final RewardRedemption redemption;
  final String? rewardName;
  final String? rewardEmoji;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PendingRedemptionTile({
    required this.redemption,
    required this.rewardName,
    required this.rewardEmoji,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(rewardEmoji ?? '🎁', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${rewardName ?? 'Gantimpala'} · ${redemption.pointsSpent} points'),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle, color: AppColors.success),
            onPressed: onApprove,
            tooltip: 'Aprubahan',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: AppColors.error),
            onPressed: onReject,
            tooltip: 'Tanggihan',
          ),
        ],
      ),
    );
  }
}

class _RewardFormResult {
  final String name;
  final String description;
  final String emoji;
  final int pointCost;
  final bool active;

  const _RewardFormResult({
    required this.name,
    required this.description,
    required this.emoji,
    required this.pointCost,
    required this.active,
  });
}

class _RewardFormDialog extends StatefulWidget {
  final Reward? existing;
  const _RewardFormDialog({this.existing});

  @override
  State<_RewardFormDialog> createState() => _RewardFormDialogState();
}

class _RewardFormDialogState extends State<_RewardFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _emojiController;
  late final TextEditingController _costController;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _emojiController = TextEditingController(text: existing?.emoji ?? '🎁');
    _costController = TextEditingController(text: existing?.pointCost.toString() ?? '');
    _active = existing?.active ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _emojiController.dispose();
    _costController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _RewardFormResult(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        emoji: _emojiController.text.trim().isEmpty ? '🎁' : _emojiController.text.trim(),
        pointCost: int.parse(_costController.text.trim()),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'I-edit ang Gantimpala' : 'Bagong Gantimpala'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      controller: _emojiController,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: const InputDecoration(labelText: 'Emoji'),
                      maxLength: 2,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Pangalan ng gantimpala'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Kailangan ng pangalan' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Deskripsyon (opsyonal)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(labelText: 'Halaga sa points'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Maglagay ng valid na numero';
                  return null;
                },
              ),
              if (isEditing) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktibo (nakikita sa anak)'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kanselahin')),
        ElevatedButton(onPressed: _submit, child: Text(isEditing ? 'I-save' : 'Gawin')),
      ],
    );
  }
}
