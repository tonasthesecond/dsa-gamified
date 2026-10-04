class_name StudentController
extends Controller
## Asks the student's code, through the battle context's StudentCode.

const CONTEXT_KEY := "student_code"


func begin(battle: Battle) -> Dictionary:
	var student_code := _student_code(battle)
	if student_code == null:
		return {"abort": "no StudentCode in the battle context under \"%s\"" % CONTEXT_KEY}
	var reply := student_code.start()
	if reply.has("abort"):
		return reply
	if reply.get("error") != null:
		return {"error": describe(reply.error, "Your Submission constructor")}
	return {}


func act(battle: Battle, unit: Combatant) -> Dictionary:
	var reply := _student_code(battle).decide(battle.state_for(unit))
	if reply.has("abort"):
		return reply
	var who := "Your decide() for %s" % unit.display_name()
	if reply.get("error") != null:
		return {"error": describe(reply.error, who, unit)}
	return parse(reply.get("action"), who)


## Returns a command such as "cleave e1 e2" as an action, or an error.
static func parse(command: Variant, who: String) -> Dictionary:
	if not command is String:
		return {"error": "%s returned something that is not a String." % who}
	var words: Array = []
	for found in RegEx.create_from_string("\\S+").search_all(command):
		words.append(found.get_string())
	if words.is_empty():
		return {"error": "%s returned an empty command. Return \"pass\" to do nothing." % who}
	return {"action": {"move": words[0], "targets": words.slice(1)}}


## Returns a runner error as one sentence for the player.
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
			return "%s %s" % [who, message]


func _student_code(battle: Battle) -> StudentCode:
	return battle.context.get(CONTEXT_KEY)
