class_name ServerConfig
extends Resource
## Every value the client needs to reach the compile service.
## Edit the values in server_config.tres, not the defaults here.

## Base URL of the compile service, without a trailing slash.
@export var server_url: String = "http://localhost:8080"
## Seconds before a submit gives up. Covers javac + TeaVM + the 5 s run.
@export var timeout_sec: float = 30.0
## Level sent with a submit when the UI does not choose one.
@export var default_level: String = "demo"
## Only derives the seed on the server; same student + level, same scenarios.
@export var student: String = "anonymous"
