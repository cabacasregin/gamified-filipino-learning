import 'package:equatable/equatable.dart';

/// A top-level MATATAG-aligned strand, e.g. "Alpabetong Filipino".
class CurriculumUnit extends Equatable {
  final String id;
  final String title;
  final String titleFilipino;
  final String description;
  final String iconEmoji;
  final int sortOrder;

  const CurriculumUnit({
    required this.id,
    required this.title,
    required this.titleFilipino,
    required this.description,
    required this.iconEmoji,
    required this.sortOrder,
  });

  factory CurriculumUnit.fromMap(Map<String, dynamic> map) {
    return CurriculumUnit(
      id: map['id'] as String,
      title: map['title'] as String,
      titleFilipino: (map['title_filipino'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      iconEmoji: (map['icon_emoji'] as String?) ?? '📘',
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'title_filipino': titleFilipino,
        'description': description,
        'icon_emoji': iconEmoji,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, title, titleFilipino, description, iconEmoji, sortOrder];
}

/// A lesson groups several [LessonItem]s within a [CurriculumUnit].
class Lesson extends Equatable {
  final String id;
  final String unitId;
  final String title;
  final int sortOrder;

  const Lesson({
    required this.id,
    required this.unitId,
    required this.title,
    required this.sortOrder,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'] as String,
      unitId: map['unit_id'] as String,
      title: map['title'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'unit_id': unitId,
        'title': title,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [id, unitId, title, sortOrder];
}

/// A single English-Filipino vocabulary/concept entry, the atomic unit of
/// both the "learn" flow and the "assessment" flow.
class LessonItem extends Equatable {
  final String id;
  final String lessonId;
  final String englishText;
  final String filipinoText;
  final String emoji;
  final String? imageUrl;
  final String? ttsTextOverride;
  final List<String> acceptedVariants;
  final int sortOrder;

  const LessonItem({
    required this.id,
    required this.lessonId,
    required this.englishText,
    required this.filipinoText,
    required this.emoji,
    this.imageUrl,
    this.ttsTextOverride,
    this.acceptedVariants = const [],
    required this.sortOrder,
  });

  /// Text to pass to the TTS engine for the "correct pronunciation" audio.
  String get pronunciationText => ttsTextOverride ?? filipinoText;

  factory LessonItem.fromMap(Map<String, dynamic> map) {
    return LessonItem(
      id: map['id'] as String,
      lessonId: map['lesson_id'] as String,
      englishText: map['english_text'] as String,
      filipinoText: map['filipino_text'] as String,
      emoji: (map['emoji'] as String?) ?? '❓',
      imageUrl: map['image_url'] as String?,
      ttsTextOverride: map['tts_text'] as String?,
      acceptedVariants: ((map['accepted_variants'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'lesson_id': lessonId,
        'english_text': englishText,
        'filipino_text': filipinoText,
        'emoji': emoji,
        'image_url': imageUrl,
        'tts_text': ttsTextOverride,
        'accepted_variants': acceptedVariants,
        'sort_order': sortOrder,
      };

  @override
  List<Object?> get props => [
        id,
        lessonId,
        englishText,
        filipinoText,
        emoji,
        imageUrl,
        ttsTextOverride,
        acceptedVariants,
        sortOrder,
      ];
}
