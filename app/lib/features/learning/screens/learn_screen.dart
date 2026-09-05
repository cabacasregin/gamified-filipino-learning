import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../providers/learn_providers.dart';
import '../widgets/flashcard.dart';
import '../widgets/points_toast.dart';

/// The low-stakes "exposure" flow for a unit: flip through every lesson item
/// as a flashcard (picture/emoji + English + Filipino + pronunciation),
/// tapping "Nakuha ko na!" (Got it!) to bank a small number of points and
/// move to the next one. Ends with a small celebration screen once every
/// card in the unit has been acknowledged.
class LearnScreen extends ConsumerWidget {
  final String unitId;

  const LearnScreen({super.key, required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(unitLearnItemsProvider(unitId));
    return Scaffold(
      appBar: AppBar(title: const Text('Matuto (Learn)')),
      body: SafeArea(
        child: AsyncView<List<LessonItem>>(
          value: itemsAsync,
          emptyMessage: 'Wala pang laman ang unit na ito. Balik ka mamaya!',
          isEmpty: (items) => items.isEmpty,
          builder: (items) => _LearnFlow(unitId: unitId, items: items),
        ),
      ),
    );
  }
}

class _LearnFlow extends ConsumerStatefulWidget {
  final String unitId;
  final List<LessonItem> items;
  const _LearnFlow({required this.unitId, required this.items});

  @override
  ConsumerState<_LearnFlow> createState() => _LearnFlowState();
}

class _LearnFlowState extends ConsumerState<_LearnFlow> {
  final _toastKey = GlobalKey<PointsToastHostState>();
  late final ConfettiController _confettiController;
  int _index = 0;
  int _sessionPoints = 0;
  bool _submitting = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    // Autoplay is a real user gesture removed from the tap that navigated
    // here, which is fine on mobile TTS but can be blocked by web autoplay
    // policies — best-effort only. The speaker button always works since a
    // manual tap is always a valid user gesture.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  LessonItem get _currentItem => widget.items[_index];
  bool get _isComplete => _index >= widget.items.length;

  Future<void> _speakCurrent() async {
    if (!mounted || _isComplete) return;
    setState(() => _isSpeaking = true);
    try {
      await ref.read(ttsServiceProvider).speak(_currentItem.pronunciationText);
    } catch (_) {
      // Swallow — pronunciation audio is a nice-to-have here, the card's
      // text is still fully readable, and the speaker button lets the
      // learner retry with an unambiguous user gesture.
    } finally {
      if (mounted) setState(() => _isSpeaking = false);
    }
  }

  Future<void> _onGotIt() async {
    if (_submitting || _isComplete) return;
    final item = _currentItem;
    setState(() => _submitting = true);
    try {
      final awarded = await ref.read(pointsRepositoryProvider).recordLearnCompletion(item.id);
      if (!mounted) return;
      _toastKey.currentState?.show(awarded);
      setState(() {
        _sessionPoints += awarded;
        _index += 1;
        _submitting = false;
      });
      if (!_isComplete) {
        await _speakCurrent();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hindi na-save ang progress: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isComplete) {
      return _CompletionView(
        totalItems: widget.items.length,
        sessionPoints: _sessionPoints,
        confettiController: _confettiController,
      );
    }

    return PointsToastHost(
      key: _toastKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            _ProgressBar(current: _index, total: widget.items.length),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: LearnFlashcard(
                    key: ValueKey(_currentItem.id),
                    item: _currentItem,
                    isSpeaking: _isSpeaking,
                    onReplayPronunciation: _speakCurrent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _onGotIt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: const Text('Nakuha ko na! (Got it!)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  const _ProgressBar({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : current / total;
    return Column(
      children: [
        Text(
          '$current / $total',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 10,
            backgroundColor: Colors.black12,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _CompletionView extends StatefulWidget {
  final int totalItems;
  final int sessionPoints;
  final ConfettiController confettiController;

  const _CompletionView({
    required this.totalItems,
    required this.sessionPoints,
    required this.confettiController,
  });

  @override
  State<_CompletionView> createState() => _CompletionViewState();
}

class _CompletionViewState extends State<_CompletionView> {
  @override
  void initState() {
    super.initState();
    // Wait for this frame (including the ConfettiWidget below) to finish
    // mounting before starting playback.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.confettiController.play());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 16),
                Text(
                  'Magaling! (Great job!)',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Natapos mo ang ${widget.totalItems} cards sa unit na ito!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.points, borderRadius: BorderRadius.circular(28)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.sessionPoints} points ngayon',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () => context.go('/student/home'),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Bumalik sa Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
        IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: widget.confettiController,
              blastDirection: math.pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 8,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [AppColors.primary, AppColors.secondary, AppColors.success, AppColors.points],
            ),
          ),
        ),
      ],
    );
  }
}
