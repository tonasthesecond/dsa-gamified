# Homework 2: UML and architecture

Each diagram is a D2 file; the `.svg` and `.png` next to it are renders
(`d2 <name>.d2 <name>.svg`). Theme and layout are set inside each file.

## 1. Use case diagram (`use_case.d2`)

The one actor is the **student**. They choose a level, read its goal, look at
the characters, write code that picks each move, submit it, and watch the
battle play out. Inside the same system, the game does the rest on its own:
it checks and prepares the code, plays the battle turn by turn, and asks the
student's code for every move.

- Submitting *includes* preparing the code, playing the battle and the replay.
- Seeing mistakes *extends* submitting: it only happens when the code is wrong.
- Grading a data-structure question *extends* asking for a move: only some
  levels ask one.

## 2. Sequence diagram (`sequence.d2`)

One submission from start to finish. The code goes to the code server, which
checks it and starts it in a sandbox. The game then plays the battle: on each
of the student's turns it sends the battle so far to the server and gets a
move back, while enemies make the move they announced. At the end the game has
a full record of the battle and plays it back as an animation.

## 3. Architecture (`architecture.d2`)

**Style: client–server, with the game split into layers.**

- **Client–server.** The game runs in the student's browser and owns every
  rule. The code server only compiles and runs student code, and knows nothing
  about the game. Student code can't be trusted, so it runs on the server in a
  sandbox with time and output limits, never in the game itself. Because the
  server holds no game rules, new levels and mechanics never require changing it.
- **Layers in the game.** Screens → coordination → game logic → game content.
  Each layer only uses the one below it, so the battle rules can be tested
  without any screen, and the screens can change without touching the rules.
- **Content as data.** Characters, moves and levels are data files, not code,
  so adding a level is mostly filling in data.
- **Play first, then replay.** The battle is computed in full, producing a
  record, and only then animated. The rules stay separate from the animation,
  and the same code on the same level always gives the same battle.
