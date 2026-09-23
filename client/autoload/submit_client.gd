extends Node
## Autoload `SubmitClient`. POSTs a Submission.java to /compile.
##
## Only the transport is judged here. Anything the server answered with a JSON
## object is a result, compile errors included: Simulation reads `status`.

## The decoded response envelope: {status, message, console, result}.
signal result_ready(envelope: Dictionary)
## The request never produced an envelope: server down, timeout, bad response.
signal submit_failed(reason: String)

var _http: HTTPRequest
var _url: String


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func submit(source: String, level: String) -> void:
	var settings := Config.settings
	_http.timeout = settings.timeout_sec
	_url = "%s/compile?level=%s&student=%s" % [
		settings.server_url.trim_suffix("/"), level.uri_encode(), settings.student.uri_encode()]
	var headers := PackedStringArray(["Content-Type: text/plain; charset=utf-8"])
	var err := _http.request_raw(_url, headers, HTTPClient.METHOD_POST, source.to_utf8_buffer())
	if err != OK:
		# Deferred so a failure always arrives after submit() returns, like a real one.
		_fail.call_deferred("could not start request to %s: %s" % [_url, error_string(err)])


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			pass
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			_fail("no server at %s" % _url)
			return
		HTTPRequest.RESULT_TIMEOUT:
			_fail("no answer within %s s from %s" % [Config.settings.timeout_sec, _url])
			return
		_:
			_fail("request to %s failed (HTTPRequest result %d)" % [_url, result])
			return
	if code != 200:
		_fail("server answered HTTP %d" % code)
		return
	var envelope: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not envelope is Dictionary:
		_fail("server response is not a JSON object")
		return
	result_ready.emit(envelope)


func _fail(reason: String) -> void:
	submit_failed.emit(reason)
