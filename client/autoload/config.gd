extends Node
## Autoload `Config`. The one place scripts read server settings from.
## The values live in res://config/server_config.tres.

const SETTINGS_PATH := "res://config/server_config.tres"

var settings: ServerConfig = load(SETTINGS_PATH)
