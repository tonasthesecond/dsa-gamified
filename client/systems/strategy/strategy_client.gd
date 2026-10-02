class_name StrategyClient
extends RefCounted
## One student's code for one battle; replies are docs/runner.md's, or {"abort": reason}.

## Everything the code printed so far.
var console: String = ""


## Makes a fresh Submission: {"error": ...} or {"abort": ...}.
func start() -> Dictionary:
	return {"error": null}


## Returns {"action": command, "error": ...} or {"abort": ...}.
func decide(_state: Dictionary) -> Dictionary:
	return {"action": "pass", "error": null}
