class_name Effect
extends Resource
## One step of a move. A move is its effects run in order, so damage, healing
## and blocking are all effects, and a new mechanic is a new subclass.
##
## An effect changes the battle only through Battle's primitives (deal_damage,
## heal, block), which log their own events: an effect never builds an event.
## It holds no battle state, so one instance is safe to share.


## Carries this step out. The target is already known to be legal.
## `scratch` is shared with the other effects of this one use of the move.
func apply(_battle: Battle, _user: Combatant, _target: Combatant, _scratch: MoveScratch) -> void:
	pass
