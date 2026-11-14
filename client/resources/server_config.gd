class_name ServerConfig
extends Resource
## Settings for reaching the compile service; edit data/server_config.tres.

@export var server_url: String = "http://localhost:8080"
## On web, the service is reached at the page's own origin + this path, and server_url is ignored.
@export var web_path: String = "/api"
## Seconds javac + TeaVM may take.
@export var timeout_sec: float = 30.0
@export var default_level: String = "demo"
## Per call to the student's code, 1 to 10000.
@export var decide_timeout_ms: int = 1000
