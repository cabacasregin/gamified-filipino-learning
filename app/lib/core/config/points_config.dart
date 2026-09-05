/// Central place for the game's point economy so design tweaks don't require
/// hunting through feature code. Mirrors the constants used by the
/// `record_learn_completion` / `record_assessment_attempt` Postgres
/// functions — keep both sides in sync if you change these.
class PointsConfig {
  /// Small reward for completing a "learn" (exposure) step.
  static const int learnCompletionPoints = 2;

  /// Base points for a correct spoken-assessment answer, before multiplier.
  static const int assessmentBasePoints = 5;

  /// Assessment answers are worth more than passive learning to push
  /// learners toward active recall.
  static const int assessmentMultiplier = 3;

  static const int assessmentCorrectPoints = assessmentBasePoints * assessmentMultiplier;
}
