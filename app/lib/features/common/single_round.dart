import 'dart:async';

import 'package:flutter/widgets.dart';

/// Shared flow for games hosted as **one step of a lesson** (`singleRound`).
///
/// A lesson step plays a single round: the game celebrates the solve briefly,
/// then auto-advances by firing the host's callback — no "next" tap, which is
/// how the lesson keeps its pace for small children. The mixin tracks whether
/// the round was flawless (no wrong attempts) so the lesson can re-queue missed
/// material, and owns the advance timer so a mid-celebration exit can't fire a
/// callback into a disposed screen.
mixin SingleRoundFlow<T extends StatefulWidget> on State<T> {
  Timer? _advanceTimer;
  bool _wrongThisRound = false;
  int _epoch = 0; // invalidates in-flight completions on reset/dispose

  /// The minimum time the child sees the solve celebration before advancing.
  static const Duration advanceDelay = Duration(milliseconds: 1500);

  /// Ceiling on waiting for celebration speech — a wedged TTS engine must
  /// never freeze the lesson.
  static const Duration _speechWaitCap = Duration(seconds: 6);

  /// Call on every wrong attempt this round.
  void noteWrongAttempt() => _wrongThisRound = true;

  /// Call when a new round starts.
  void resetRoundFlaws() {
    _wrongThisRound = false;
    _epoch++;
  }

  /// Call when the round is solved: reports completion (and whether it was
  /// flawless) to [onRoundComplete] once BOTH [advanceDelay] has elapsed and
  /// [afterSpeech] (the solve-celebration utterance) has finished — so the
  /// next step's instruction never cuts the praise off mid-word. No-op when
  /// null — standalone pages keep their own "next" flow.
  void scheduleRoundComplete(
    void Function({required bool flawless})? onRoundComplete, {
    Future<void>? afterSpeech,
  }) {
    if (onRoundComplete == null) return;
    final flawless = !_wrongThisRound;
    final epoch = _epoch;
    _advanceTimer?.cancel();
    final minDelay = Completer<void>();
    _advanceTimer = Timer(advanceDelay, minDelay.complete);
    final speech = (afterSpeech ?? Future<void>.value())
        .timeout(_speechWaitCap, onTimeout: () {})
        .catchError((_) {});
    Future.wait([minDelay.future, speech]).then((_) {
      if (mounted && epoch == _epoch) onRoundComplete(flawless: flawless);
    });
  }

  /// Call from the game's load path when it turns out this game can't start
  /// (not enough content in the scoped pool). In a lesson that must never
  /// strand the child on a dead screen — the step quietly skips itself.
  void skipUnplayableRound(void Function({required bool flawless})? onRoundComplete) {
    if (onRoundComplete == null) return;
    _advanceTimer?.cancel();
    _advanceTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) onRoundComplete(flawless: true);
    });
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _epoch++;
    super.dispose();
  }
}
