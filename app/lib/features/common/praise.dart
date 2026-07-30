import 'dart:math';

/// Short spoken praise, varied so it stays alive across a lesson. The single
/// most motivating moment for a small child must never be silent — every game
/// speaks one of these (plus the answer word) on a correct answer.
const List<String> kPraise = ['Yes!', 'Great job!', 'You got it!', 'Wow!'];

String praiseLine(Random random) => kPraise[random.nextInt(kPraise.length)];
