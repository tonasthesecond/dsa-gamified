class_name ServerConfig
extends Resource
## Every value the client needs to reach the compile service.
## Edit the values in server_config.tres, not the defaults here.

## Base URL of the compile service, without a trailing slash.
@export var server_url: String = "http://localhost:8080"
## Seconds the compile step may take (javac + TeaVM) before a submit gives up.
@export var timeout_sec: float = 30.0
## The encounter a submit plays: res://levels/<default_level>.tres.
@export var default_level: String = "demo"
## Unused since the battle moved into the client: the seed belongs to the level.
@export var student: String = "anonymous"
## How long the student's code may take per call, including its constructor.
## The compile service accepts 1 to 10000.
@export var decide_timeout_ms: int = 1000
