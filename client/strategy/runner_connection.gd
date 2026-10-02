class_name RunnerConnection
extends RefCounted
## Blocking HTTP to the compile service, for use off the main thread.
##
## A battle asks the student's code once per unit per turn, so each call's
## latency counts. HTTPRequest only finishes on a later frame, about 35 ms a
## call; polling HTTPClient in a loop is about 2 ms end to end.

var _client := HTTPClient.new()
var _host: String
var _port: int
var _tls: bool


## `server_url` such as "http://localhost:8080", no trailing slash needed.
func _init(server_url: String) -> void:
	var rest := server_url.strip_edges().trim_suffix("/")
	_tls = rest.begins_with("https://")
	rest = rest.trim_prefix("https://").trim_prefix("http://")
	var colon := rest.rfind(":")
	if colon >= 0:
		_host = rest.substr(0, colon)
		_port = int(rest.substr(colon + 1))
	else:
		_host = rest
		_port = 443 if _tls else 80


## POSTs `body` to `path` (with its query) and returns the JSON object the
## service answered, or {"transport": reason} if no answer came in `timeout_ms`.
func post(path: String, body: String, timeout_ms: int) -> Dictionary:
	var deadline := Time.get_ticks_msec() + timeout_ms
	var failure := _connect(deadline)
	if not failure.is_empty():
		return {"transport": failure}
	var err := _client.request(HTTPClient.METHOD_POST, path,
		["Content-Type: text/plain; charset=utf-8"], body)
	if err != OK:
		return {"transport": "could not send to %s: %s" % [_where(path), error_string(err)]}
	while _client.get_status() == HTTPClient.STATUS_REQUESTING:
		_client.poll()
		if Time.get_ticks_msec() > deadline:
			_client.close()
			return {"transport": "no answer within %d ms from %s" % [timeout_ms, _where(path)]}
		OS.delay_usec(50)
	if not _client.has_response():
		_client.close()
		return {"transport": "no response from %s" % _where(path)}
	var code := _client.get_response_code()
	var bytes := PackedByteArray()
	while _client.get_status() == HTTPClient.STATUS_BODY:
		_client.poll()
		bytes.append_array(_client.read_response_body_chunk())
		if Time.get_ticks_msec() > deadline:
			_client.close()
			return {"transport": "answer from %s did not finish in time" % _where(path)}
	if code != 200:
		return {"transport": "%s answered HTTP %d" % [_where(path), code]}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary:
		return {"transport": "%s did not answer with a JSON object" % _where(path)}
	return parsed


func close() -> void:
	_client.close()


## Connects, or reuses the open connection. Empty on success, else why not.
func _connect(deadline: int) -> String:
	if _client.get_status() == HTTPClient.STATUS_CONNECTED:
		return ""
	_client.close()
	var err := _client.connect_to_host(_host, _port, TLSOptions.client() if _tls else null)
	if err != OK:
		return "could not connect to %s:%d: %s" % [_host, _port, error_string(err)]
	while _client.get_status() in [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING]:
		_client.poll()
		if Time.get_ticks_msec() > deadline:
			_client.close()
			return "no server at %s:%d" % [_host, _port]
		OS.delay_usec(100)
	if _client.get_status() != HTTPClient.STATUS_CONNECTED:
		return "no server at %s:%d" % [_host, _port]
	return ""


func _where(path: String) -> String:
	return "%s://%s:%d%s" % ["https" if _tls else "http", _host, _port, path.get_slice("?", 0)]
