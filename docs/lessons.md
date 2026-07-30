# Lessons — the Duolingo-ABC-style play loop

The 2026-07 revamp replaces the "grind one game until an XP bar fills" level session with
**lessons**: short, finite, mixed-exercise sessions with a visible finish line, a guide
character, and a celebration at the end. The *mechanic* stays the Gleitman & Rozin
syllabary curriculum ([`curriculum.md`](curriculum.md)); this document covers the
*engagement shell* around it.

## Why (what was wrong)

| Old | Problem for a pre-reader |
|---|---|
| One random game per level, repeated until an XP goal | No variety, no visible end, pacing sags |
| Leave early → the whole session reverts | Punishing; a child who stops loses everything |
| Feedback & dialogs are written text | The target user *cannot read* |
| "Find the **cat**!" spoken aloud in Find-the-Character | Speaks the answer — the reading task degenerates to listening |
| Build-a-Word shows the printed target word | Children letter-shape-match instead of blending by sound |
| A "next" tap after every round | Halves pace; small children stall |

## The loop

```
Home (level path) ─ Play ─▶ Lesson (≈8 steps) ─▶ Celebration (1–3 stars) ─▶ Home
                              │                       │
                              ├ Meet-symbol intros    └ after final lesson of the
                              ├ mixed single-round      level: level-up overlay
                              └ exercises (auto-advance)
```

* A **level** = `lessons` (2–3) short lessons; finishing all of them levels up.
  Progress is *lessons completed*, not raw XP (XP remains underneath for the
  decoupled rewards layer — achievements, streaks).
* A **lesson** = an ordered plan of steps built by [`LessonPlan`](../app/lib/learning/lesson_plan.dart):
  * every not-yet-met symbol → a **Meet card** immediately followed by an exercise
    *focused on that symbol* (guarantees new symbols get practiced — this also fixes
    the working-set-cap starvation of unseen items);
  * remaining slots are filled from the level's game list in shuffled "bags" so types
    vary and never repeat back-to-back;
  * an exercise answered wrong is **re-queued** once near the end ("let's try that
    one again"), capped so a lesson always ends.
* Each exercise is **one round** of a game (`singleRound: true`): on solve the game
  celebrates briefly and **auto-advances** (no "next" tap). The segmented progress
  bar at the top fills one notch per step.
* **Leaving early keeps progress** — the lesson simply doesn't count. No revert.

## The guide character

A small cast of emoji guides (one per level, deterministic) lives in the lesson
header and the celebration screen ([`guide_character.dart`](../app/lib/features/common/guide_character.dart)).
Moods: `idle` (breathing bob), `happy` (jump on a correct answer), `sad`
(sympathetic wobble on a miss), `cheer` (celebration dance). The guide is the app's
face until real art lands; it shares the emoji art language of the pictographs.

## Pre-reader UI rules (enforced in every screen)

1. **Nothing load-bearing is written.** Instructions are spoken on entry; feedback is
   animation + audio; dialogs use big icons (▶ keep playing / 🚪 leave) and speak
   their question aloud.
2. **Tap-to-hear everywhere** stays a hard invariant.
3. **Never speak the answer to a *reading* task.** Listening tasks name the target
   ("Tap the cat!"); reading tasks frame it generically ("Read the word — find its
   picture!") and rely on tap-the-word-to-hear as the scaffold.
4. **Big targets, no dead ends, forgiving errors** — wrong answers wobble and
   re-teach, they never block or punish.
5. **Right and wrong must be audibly distinct.** Correct → varied praise + the
   word ("Great job! cat!"); wrong → "Oops!" + the truthful label of what was
   actually touched ("Oops! That is the dog.") — never the bare target word
   while the child's finger is on a mismatched picture. Every seam (home,
   profiles, dialog choices, resume) is narrated; identical utterances within
   ~600 ms are debounced against mashing.

## Exercise types

Existing (all upgraded to the single-round protocol):
`listen_and_pick`, `find_the_character`, `sound_match`, `families`, `build_a_word`
(target is now heard/pictured, printed word revealed *after* solving), `fill_blank`.

New in the revamp:

| id | One-liner | Skill |
|---|---|---|
| `picture_to_word` | See a picture, hear its name, pick the **written word** among 3 | sound→print (the reverse of Find-the-Character) |
| `symbol_hunt` | "Find **all** the cats!" — tap every target in a 6-cell grid | recognition, multi-tap fun |
| `echo_read` | Tap the tokens of a phrase **left-to-right**, hearing each, then hear it read fluently | reading direction, fluency (uses `phrases.v1.json`, falls back to pictograph rows) |
| `blend_reveal` | Watch two syllable cards **slide together** and blend aloud, then pick the word that was made | blending by ear (recognition-side of Build-a-Word) |

## Where things live

| Piece | File |
|---|---|
| Lesson plan builder (pure Dart) | `app/lib/learning/lesson_plan.dart` |
| Lesson host screen | `app/lib/features/lesson/lesson_screen.dart` |
| Celebration (stars + confetti) | `app/lib/features/lesson/celebration.dart` |
| Guide character | `app/lib/features/common/guide_character.dart` |
| Lesson counts + game ramp | `content/curriculum.v1.json` (`lessons` per level) — **mirrored** to `app/assets/content/` |
| Lesson tracking | `ProgressService.completeLesson()` / `lessonsIntoLevel` |
