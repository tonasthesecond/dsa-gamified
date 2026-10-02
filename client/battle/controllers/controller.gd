class_name Controller
extends Resource
## Picks the actions of one side's units. The battle assigns a controller to a
## side; a unit never knows who controls it, so the same UnitDef can be the
## student's in one battle and an AI's in the next. A new kind of decider (an
## AI, the student's code, another player) is a new subclass.
##
## Controllers hold no battle state, so one instance can be shared.


## Once, before the first turn. {} to go on, {"error": message} to end the
## battle as a loss with that error, {"abort": ...} if it cannot run at all.
func begin(_battle: Battle) -> Dictionary:
	return {}


## At the start of each turn: what this unit telegraphs, {"move": Move,
## "targets": Array[Combatant]}, which the log shows and every state carries
## as its intent; or {} to telegraph nothing.
func plan(_battle: Battle, _unit: Combatant) -> Dictionary:
	return {}


## When this unit acts: {"action": {"move": id, "targets": [ids]}}, the
## parts of a command like "attack e1", with no ids for a move on the user
## itself; {"error": message} to end the battle as a loss; {"abort": ...} if
## the battle cannot go on.
func act(_battle: Battle, _unit: Combatant) -> Dictionary:
	return {"action": {"move": "pass", "targets": []}}


## The action from act turned out to be illegal, for the reason `problem`.
## Return an error to end the battle as a loss, or "" to let it fizzle.
func refuse(_battle: Battle, _unit: Combatant, problem: String) -> String:
	return problem
