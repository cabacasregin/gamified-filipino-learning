import 'package:flutter/material.dart';

import '../../../core/models/curriculum_models.dart';
import '../../../core/theme/app_theme.dart';

/// A single flashcard for the "Learn" flow: a picture (image if the item has
/// one, otherwise its emoji), the Filipino term (the target language, given
/// visual emphasis), the English gloss, and a button to (re)play its
/// pronunciation via TTS.
class LearnFlashcard extends StatelessWidget {
  final LessonItem item;
  final bool isSpeaking;
  final VoidCallback onReplayPronunciation;

  const LearnFlashcard({
    super.key,
    required this.item,
    required this.onReplayPronunciation,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardVisual(item: item),
            const SizedBox(height: 24),
            Text(
              item.filipinoText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              item.englishText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onReplayPronunciation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
              ),
              icon: Icon(isSpeaking ? Icons.volume_up_rounded : Icons.volume_up_outlined),
              label: const Text('Bigkasin (Say it)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardVisual extends StatelessWidget {
  final LessonItem item;
  const _CardVisual({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          imageUrl,
          height: 140,
          width: 140,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _EmojiVisual(emoji: item.emoji),
        ),
      );
    }
    return _EmojiVisual(emoji: item.emoji);
  }
}

class _EmojiVisual extends StatelessWidget {
  final String emoji;
  const _EmojiVisual({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Text(emoji, style: const TextStyle(fontSize: 96));
  }
}
