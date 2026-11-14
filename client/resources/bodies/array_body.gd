class_name ArrayBody
extends Body
## An array of distinct whole numbers, so a question about the position of a value has one answer.

@export var length: int = 6
@export var min_value: int = 1
## Must leave room for `length` distinct values.
@export var max_value: int = 50


func generate(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array = range(min_value, max_value + 1)
	var count := mini(length, pool.size())
	# A partial shuffle: the first `count` of the pool, picked without repeats.
	for i in count:
		var j := rng.randi_range(i, pool.size() - 1)
		var picked: int = pool[j]
		pool[j] = pool[i]
		pool[i] = picked
	return {"kind": "array", "values": pool.slice(0, count)}


func values(body: Dictionary) -> Array:
	return body.get("values", [])
