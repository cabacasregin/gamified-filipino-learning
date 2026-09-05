import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/answer_matcher.dart';
import '../../../core/widgets/async_view.dart';

/// Items for one unit's spoken-assessment session, in curriculum order.
final _unitAssessmentItemsProvider =
    FutureProvider.family<List<LessonItem>, String>((ref, unitId) {
  return ref.watch(contentRepositoryProvider).fetchUnitItems(unitId);
});

/// How many times a learner may retry a single item before we offer a
/// "skip for now" escape hatch — chosen so a wrong guess or two doesn't
/// feel punishing, but a broken mic/no-speech-detected loop doesn't trap
/// the learner forever either.
const int _maxAttemptsPerItem = 3;

enum _Readiness { checking, ready, noSpeechSupport, micDenied, micPermanentlyDenied }

/// Spoken-answer "assessment" flow: shows one [LessonItem] at a time
/// (prompt only — never the Filipino answer text), records the learner's
/// attempt to say it aloud, grades it with [AnswerMatcher], and awards
/// multiplier points for correct answers via [PointsRepository].
class AssessmentScreen extends ConsumerStatefulWidget {
  final String unitId;
  const AssessmentScreen({super.key, required this.unitId});

  @override
  ConsumerState<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends ConsumerState<AssessmentScreen> {
  _Readiness _readiness = _Readiness.checking;

  int _index = 0;
  int _attemptsForCurrent = 0;
  bool _isListening = false;
  bool _showCorrection = false;
  bool _celebrating = false;
  bool _finished = false;

  int _sessionPoints = 0;
  int _lastAwarded = 0;
  final Set<String> _correctItemIds = {};

  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _checkReadiness();
  }

  @override
  void dispose() {
    _confetti.dispose();
    ref.read(speechRecognitionServiceProvider).cancel();
    super.dispose();
  }

  Future<void> _checkReadiness() async {
    final speech = ref.read(speechRecognitionServiceProvider);
    bool available;
    try {
      available = await speech.init();
    } catch (_) {
      available = false;
    }
    if (!mounted) return;
    if (!available) {
      setState(() => _readiness = _Readiness.noSpeechSupport);
      return;
    }

    PermissionStatus status = PermissionStatus.granted;
    try {
      status = await Permission.microphone.request();
    } catch (_) {
      // permission_handler has no implementation on this platform (e.g.
      // some web builds) — speech_to_text's own initialize() already
      // triggered the browser/OS mic prompt above, so proceed.
      status = PermissionStatus.granted;
    }
    if (!mounted) return;
    if (status.isGranted || status.isLimited) {
      setState(() => _readiness = _Readiness.ready);
    } else if (status.isPermanentlyDenied) {
      setState(() => _readiness = _Readiness.micPermanentlyDenied);
    } else {
      setState(() => _readiness = _Readiness.micDenied);
    }
  }

  Future<void> _listen(LessonItem item) async {
    if (_isListening) return;
    setState(() {
      _isListening = true;
      _showCorrection = false;
    });

    final speech = ref.read(speechRecognitionServiceProvider);
    String? transcript;
    try {
      transcript = await speech.listenOnce();
    } catch (_) {
      transcript = null;
    }
    if (!mounted) return;

    final isCorrect = transcript != null && AnswerMatcher.isCorrect(transcript, item);

    int awarded = 0;
    try {
      awarded = await ref.read(pointsRepositoryProvider).recordAssessmentAttempt(
            lessonItemId: item.id,
            transcript: transcript ?? '',
            isCorrect: isCorrect,
          );
    } catch (_) {
      // Attempt history / points write failed (e.g. offline) — still give
      // the learner local feedback rather than freezing the flow.
    }
    if (!mounted) return;

    if (isCorrect) {
      setState(() {
        _isListening = false;
        _sessionPoints += awarded;
        _lastAwarded = awarded;
        _correctItemIds.add(item.id);
        _celebrating = true;
      });
      _confetti.play();
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      _advance();
    } else {
      setState(() {
        _isListening = false;
        _attemptsForCurrent++;
        _showCorrection = true;
      });
      unawaited(ref.read(ttsServiceProvider).speak(item.pronunciationText));
    }
  }

  void _advance() {
    setState(() {
      _celebrating = false;
      _showCorrection = false;
      _attemptsForCurrent = 0;
      _index++;
    });
  }

  void _skip() {
    _advance();
  }

  @override
  Widget build(BuildContext context) {
    switch (_readiness) {
      case _Readiness.checking:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case _Readiness.noSpeechSupport:
        return _buildMessageScreen(
          icon: Icons.mic_off_rounded,
          title: 'Hindi available ang speech recognition',
          message:
              'Kailangan ng assessment ang microphone at speech-recognition support ng device o browser mo. '
              'Subukan sa ibang device o i-update ang iyong browser, o bumalik sa Home.',
          primaryAction: null,
        );
      case _Readiness.micDenied:
        return _buildMessageScreen(
          icon: Icons.mic_none_rounded,
          title: 'Kailangan ng microphone access',
          message:
              'Para masuri namin ang bigkas mo, payagan muna ang app na gamitin ang microphone.',
          primaryAction: ElevatedButton(
            onPressed: _checkReadiness,
            child: const Text('Payagan ulit'),
          ),
        );
      case _Readiness.micPermanentlyDenied:
        return _buildMessageScreen(
          icon: Icons.settings_rounded,
          title: 'Naka-block ang microphone',
          message:
              'Na-block na ang microphone permission ng app na ito. Buksan ang Settings ng device mo '
              'at payagan ang microphone para sa app, tapos bumalik dito.',
          primaryAction: ElevatedButton(
            onPressed: openAppSettings,
            child: const Text('Buksan ang Settings'),
          ),
        );
      case _Readiness.ready:
        break;
    }

    final itemsAsync = ref.watch(_unitAssessmentItemsProvider(widget.unitId));
    return Scaffold(
      appBar: AppBar(title: const Text('Subukan')),
      body: SafeArea(
        child: AsyncView<List<LessonItem>>(
          value: itemsAsync,
          emptyMessage: 'Wala pang laman ang unit na ito.',
          isEmpty: (data) => data.isEmpty,
          builder: (items) {
            if (_finished || _index >= items.length) {
              return _buildSummary(items.length);
            }
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                _buildItemView(items[_index], items.length),
                ConfettiWidget(
                  confettiController: _confetti,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  numberOfParticles: 24,
                  colors: const [
                    AppColors.primary,
                    AppColors.secondary,
                    AppColors.success,
                    AppColors.points,
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageScreen({
    required IconData icon,
    required String title,
    required String message,
    required Widget? primaryAction,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subukan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.secondary),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (primaryAction != null) ...[primaryAction, const SizedBox(height: 12)],
              TextButton(
                onPressed: () => context.go('/student/home'),
                child: const Text('Bumalik sa Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemView(LessonItem item, int total) {
    final progress = (_index) / total;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 8),
          Text('Tanong ${_index + 1} / $total', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(item.emoji, style: const TextStyle(fontSize: 96)),
          const SizedBox(height: 12),
          Text(
            item.englishText,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.black54, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          Text(
            'Sabihin sa Filipino:',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 28),
          if (_celebrating)
            _buildCelebration()
          else if (_showCorrection)
            _buildCorrection(item)
          else
            _buildMicButton(item),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildMicButton(LessonItem item) {
    return Column(
      children: [
        GestureDetector(
          onTap: _isListening ? null : () => _listen(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isListening ? AppColors.error : AppColors.primary,
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? AppColors.error : AppColors.primary).withValues(alpha: 0.35),
                  blurRadius: _isListening ? 24 : 12,
                  spreadRadius: _isListening ? 6 : 2,
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening ? 'Nakikinig... magsalita ka na!' : 'I-tap para magsalita',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildCelebration() {
    return Column(
      children: [
        const Text('🎉', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 8),
        const Text(
          'Tama!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.success),
        ),
        const SizedBox(height: 4),
        Text(
          _lastAwarded > 0 ? '+$_lastAwarded points' : 'Naitala na ang tamang sagot mo!',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildCorrection(LessonItem item) {
    final attemptsLeft = _maxAttemptsPerItem - _attemptsForCurrent;
    final canSkip = attemptsLeft <= 0;
    return Column(
      children: [
        const Icon(Icons.replay_rounded, color: AppColors.error, size: 40),
        const SizedBox(height: 8),
        const Text(
          'Muli lang! Ito ang tamang sabihin:',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          item.filipinoText,
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => ref.read(ttsServiceProvider).speak(item.pronunciationText),
          icon: const Icon(Icons.volume_up_rounded),
          label: const Text('Pakinggan ulit'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _listen(item),
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Subukan Muli'),
        ),
        if (canSkip) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skip,
            child: const Text('Laktawan muna (Skip for now)'),
          ),
        ],
      ],
    );
  }

  Widget _buildSummary(int total) {
    final correct = _correctItemIds.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            Text(
              'Tapos na ang Assessment!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('$correct / $total tama', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⭐', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 6),
                Text(
                  '+$_sessionPoints points',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.points),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/student/home'),
              child: const Text('Bumalik sa Home'),
            ),
          ],
        ),
      ),
    );
  }
}
