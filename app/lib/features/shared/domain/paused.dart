import 'package:formation/features/shared/domain/models.dart';

/// Why [stock] isn't scoring, in the Assistant Manager's words. Written here
/// rather than asked of the AI: it's the same answer every time, so it costs
/// no credit and can't be wrong.
///
/// [XStock.notScoring] is the backend's label (NOT_SCORING_LABELS in
/// `backend/src/scoring/engine/eligibility.ts`).
({String question, String answer}) pausedExplanation(XStock stock) {
  final symbol = stock.symbol;
  const comeback =
      'You can still pick it, buy it or sell it, but it banks nothing for now. Once its price has been '
      'reliable for a full day, it starts scoring again by itself.';

  final answer = switch (stock.notScoring) {
    'thin market' =>
      "$symbol isn't scoring because it isn't traded much right now. Very little money moves through "
          'it: buying \$500 and selling straight back would lose more than 2%. A price like that is cheap '
          "to push around, so it can't count for points, and buying or selling it can cost you more than "
          'it should. $comeback',
    'price not updating' =>
      "$symbol isn't scoring because its price has barely changed while the market moved. That usually "
          "means hardly anyone is trading it, so the price we see isn't a real one. $comeback",
    'stale price' || 'no price' =>
      "$symbol isn't scoring because we haven't had a fresh price for it lately, so there's nothing "
          'reliable to score. $comeback',
    'erratic price' =>
      "$symbol isn't scoring because its price has been jumping around more than a real share price "
          "would. Points from a price like that wouldn't be fair, to you or anyone else. $comeback",
    'price recovering' =>
      "$symbol's price looks reliable again, so it's serving a day's wait before it scores. That stops a "
          'flaky price flickering in and out of the game. It starts scoring again once the day is up.',
    _ => "$symbol isn't scoring because its price can't be trusted right now. $comeback",
  };
  return (question: "Why isn't $symbol scoring?", answer: answer);
}
