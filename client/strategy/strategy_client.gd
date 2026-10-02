class_name StrategyClient
extends RefCounted
## One student's code for one battle, as StudentController sees it. The replies
## are server/docs/runner.md's: `error` is null or {kind, message, ...}.
## {"abort": message} instead means the code could not be reached at all.

## Everything the code printed so far, call after call.
var console: String = ""


## A fresh instance of the student's class. {"error": ...} or {"abort": ...}.
func start() -> Dictionary:
	return {"error": null}


## {"action": ..., "error": ...} or {"abort": ...}.
func decide(_state: Dictionary) -> Dictionary:
	return {"action": "pass", "error": null}
