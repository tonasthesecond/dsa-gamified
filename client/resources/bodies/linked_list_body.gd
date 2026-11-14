class_name LinkedListBody
extends Body
## A singly linked list as a table of nodes in id order, not list order, so the student has to follow `next` from `head`.

@export var min_length: int = 3
@export var max_length: int = 9
@export var min_value: int = 1
@export var max_value: int = 50


func generate(rng: RandomNumberGenerator) -> Dictionary:
	var count := rng.randi_range(min_length, max_length)
	var ids: Array[String] = []
	for i in count:
		ids.append("n%d" % (i + 1))
	var order := ids.duplicate()
	for i in range(count - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swapped: String = order[j]
		order[j] = order[i]
		order[i] = swapped
	var linked: Dictionary = {}
	for i in count:
		linked[order[i]] = {"value": rng.randi_range(min_value, max_value),
			"next": order[i + 1] if i + 1 < count else null}
	var nodes: Dictionary = {}
	for id in ids:
		nodes[id] = linked[id]
	return {"kind": "linked_list", "head": order[0], "nodes": nodes}


func values(body: Dictionary) -> Array:
	var found: Array = []
	var nodes: Dictionary = body.get("nodes", {})
	var at: Variant = body.get("head")
	while at != null and nodes.has(at) and found.size() < nodes.size():
		found.append(nodes[at].value)
		at = nodes[at].next
	return found
