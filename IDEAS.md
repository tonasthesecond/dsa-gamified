# Ideas

Scratch notes, **not to be implemented yet**. Nothing here is decided; pick from
it when designing monsters and levels.

## Monsters

Each monster kind is one data structure (its body) and one crit question. A
right answer sent with a move aimed at it is a crit.

| Monster | Body | Crit question | DSA idea |
|---|---|---|---|
| Worm | linked list | middle value (cut it in half) | fast/slow pointers |
| Ouroboros | linked list that may loop | node where the cycle starts, or null | Floyd's cycle detection |
| Centipede | linked list | value k from the tail | two pointers |
| Swarm | array | index of the smallest value, or the array sorted | linear scan, sorting |
| Mimic Row | sorted array + target k | index of k | binary search |
| Serpent | rotated sorted array | index where it rotates | binary search |
| Leech Trail | array of ints | largest subarray sum | Kadane |
| Twin Imps | array + k | two indices that sum to k | hash map |
| Doppelganger | array | first value seen twice | hash set |
| Bracket Golem | string of brackets | index of the first mismatch, or -1 | stack |
| Ghost Conga | list of queue operations | who is at the front after them | queue |
| Treant | binary tree (node table) | height | recursion |
| Hydra | tree | number of leaves (heads to cut) | traversal |
| Hive Queen | array | is it a valid min-heap, or the k-th smallest | heap |
| Spider | graph of web nodes | fewest hops from a to b | BFS |
| Labyrinth Golem | grid | shortest path length | BFS on a grid |
| Lich Ritual | tasks with prerequisites | a valid order | topological sort |
| Coin Mimic | coins + an amount | fewest coins | DP |
| Mirror Wraith | string | longest palindrome, or "is it one" | two pointers / DP |

## Level rules

On top of the monster crits. Each one either gates (a wrong answer bounces the
move) or gives a bonus.

| Rule | Needs an answer? | DSA idea |
|---|---|---|
| Hit the lowest-hp enemy first | no, judged from the target | min / priority queue |
| Median of every value in every body | yes | sorting / selection |
| Kill enemies in order of some key | no | priority queue |
| Merge every monster's sorted array | yes | k-way merge |
| Values every body shares | yes | set intersection |
| Running median of every value seen this battle | yes | two heaps |
| Has this exact body appeared before? | yes | hashing |

The last two lean on bodies re-rolling after a crit: the student has to keep a
structure in fields across turns, not just call `sort`.

## Open questions

- A first-meeting screen per monster that introduces it; a tip is one part of it.
  Needs a memory of which monsters the player has met.
- Separate crit answers per target for multi-target moves, e.g. `cleave` on two
  Worms (today one `crit` answer is judged against each target).
- Whether the log should say a crit or a re-roll happened (today a crit is just
  an extra `damage` event with the same `move`, and a re-roll is silent).
- Whether a wrong answer should ever cost something, so wrong and none differ.
