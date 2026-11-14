---
title: Feasibility Study - A Game for Learning Data Structures and Algorithms
---
# 1. Project Description

A browser game that teaches data structures and algorithms. The player writes Java code that controls a character in a turn-based battle: the game gives the code the state of the battle, and the code returns a decision.

Some levels are designed so that only a particular technique wins it, so the student learns by needing it. When the battle ends, it plays back on screen as an animation.

# 2. Scope

- Writing and submitting Java code from inside the game
- Battles that run using the submitted code
- An animated replay of each battle
- A set of hand-designed levels, each built around one idea

# 3. Technical Approach

Two parts talk to each other over HTTP, the same way a browser talks to a website.

**The game.** Built in Godot, a free game engine that can export to a web page. It owns every rule: units, moves, enemy behavior, win and loss. It runs the whole battle first, then plays it back.

**The code runner.** A small Java server. Whenever the game needs a decision, it sends the battle state here. The server compiles the student's code with `javac` (Java's standard compiler), translates it to JavaScript with TeaVM so it can be run in a controlled way, and sends the decision back. The state and the decision are both plain JSON: a dict is a dict, a list is a list.

**Status.** A prototype already runs the full chain: a test submission is compiled, run, and its result shows up in the game. An earlier attempt using WebAssembly failed and was replaced, so the biggest technical unknown has been tested.

# 4. Resources

- **People:** one developer, plus an AI coding assistant.
- **Software:** Godot 4.7, Java 17, Node.js, TeaVM 0.11.0. All free and open source.
- **Hosting:** TBA

# 5. Schedule

| Weeks | Work |
|---|---|
| 1–2 | Separate the code runner from the game and define the messages between them |
| 3–5 | Build the battle system in Godot |
| 6–7 | Tests, cleanup, put the server online |
| 8–10 | Build the levels |
| 11 | Test with real students |
| 12 | Buffer, documentation, final report |

# 6. Risks

**Untrusted code.** Any student can submit code that never finishes or misbehaves. Stronger protection might be needed.

**Speed.** One battle can need over a hundred round trips to the server. The delay will be measured early, and the design chosen to keep it low.

**Incomplete Java support.** TeaVM reimplements only part of Java's standard library, so some student code could fail.

**Level design overruns.** Some levels would be designed to have mechanics relating to course material. This could take time.

**One developer, fixed deadline.** There is no one else to hand work to. 
