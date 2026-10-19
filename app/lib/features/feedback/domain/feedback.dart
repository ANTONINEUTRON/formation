/// What a piece of feedback is about. Sent to the backend by [name].
enum FeedbackKind {
  bug('Bug', 'What happened, and what did you expect?'),
  idea('Idea', 'What would make Formation better?'),
  other('Other', "What's on your mind?");

  const FeedbackKind(this.label, this.hint);

  final String label;

  /// Placeholder for the message, so the Manager knows what helps.
  final String hint;
}

/// Feedback limits, matching the backend's.
abstract final class FeedbackLimits {
  static const minMessage = 3;
  static const maxMessage = 2000;
  static const maxScreenshotBytes = 5000000;
  static const perHour = 5;
}
