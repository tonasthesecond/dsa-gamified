extends Node
## Server settings, from data/server_config.tres; on web, the service is on the page's own origin.

var settings: ServerConfig = _load()


func _load() -> ServerConfig:
	var loaded: ServerConfig = load("res://data/server_config.tres")
	if not OS.has_feature("web"):
		return loaded
	var web: ServerConfig = loaded.duplicate()
	web.server_url = str(JavaScriptBridge.eval("location.origin")) + loaded.web_path
	return web
