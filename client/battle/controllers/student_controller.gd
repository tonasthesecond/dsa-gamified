class_name StudentController
extends Controller
## The student's code picks the actions. It reaches that code through the
## StrategyClient the host put in the battle's context under "strategy", and
## asks it once per unit per turn, with the state taken right then. The code
## answers with a command, "attack e1", which parse splits for the battle.
##
## Anything the code does wrong ends the battle as a loss with the error set:
## misbehaviour is part of playing, not a failure of the game.

const CONTEXT_KEY := "strategy"


func begin(battle: Battle) -> Dictionary:
	var client := _client(battle)
	if client == null:
		return {"abort": "no StrategyClient in the battle context under \"%s\"" % CONTEXT_KEY}
	var reply := client.start()
	if reply.has("abort"):
		return reply
	if reply.get("error") != null:
		return {"error": describe(reply.error, "Your Submission constructor")}
	return {}


func act(battle: Battle, unit: Combatant) -> Dictionary:
	var reply := _client(battle).decide(battle.state_for(unit))
	if reply.has("abort"):
		return reply
	var who := "Your decide() for %s" % unit.display_name()
	if reply.get("error") != null:
		return {"error": describe(reply.error, who, unit)}
	return parse(reply.get("action"), who)


## A command, "smite e1" or "cleave e1 e2" or "block", as an action: the first
## word is the move, the rest are target ids. Words are split on any spaces.
static func parse(command: Variant, who: String) -> Dictionary:
	if not command is String:
		return {"error": "%s returned something that is not a String." % who}
	var words: Array = []
	for found in RegEx.create_from_string("\\S+").search_all(command):
		words.append(found.get_string())
	if words.is_empty():
		return {"error": "%s returned an empty command. Return \"pass\" to do nothing." % who}
	return {"action": {"move": words[0], "targets": words.slice(1)}}


## One sentence for the player out of a runner error, server/docs/runner.md.
static func describe(error: Dictionary, who: String, unit: Combatant = null) -> String:
	var message: String = error.get("message", "")
	match error.get("kind"):
		"threw":
			var exception: String = error.get("exception", "")
			var text := "%s threw %s" % [who, exception if not exception.is_empty() else "an error"]
			return text + (": " + message if not message.is_empty() else ".")
		"returned_null":
			return "Your decide() returned null for %s. Return \"pass\" if you want to do nothing." % (
				unit.display_name() if unit != null else "a unit")
		"crashed":
			return "%s crashed: %s" % [who, message]
		_:
			# timeout and output_limit messages already read as the rest of a sentence.
			return "%s %s" % [who, message]


func _client(battle: Battle) -> StrategyClient:
	return battle.context.get(CONTEXT_KEY)
