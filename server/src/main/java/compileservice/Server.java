package compileservice;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.regex.Pattern;
import javax.tools.*;
import org.teavm.diagnostics.DefaultProblemTextConsumer;
import org.teavm.tooling.TeaVMTool;
import com.sun.net.httpserver.*;
import java.io.ByteArrayOutputStream;

/**
 * Runs student code for the Godot client and knows nothing about the game:
 * /build compiles a Submission, /start makes a fresh one, /decide hands it a
 * state and returns its command, /close throws the build away. See ../docs/runner.md.
 */
public class Server {
    private static final int MAX_BODY_BYTES = 50_000;
    static final int NODE_HEAP_MB = 256;
    /** Per /decide or /start call. The client picks its own with timeout_ms, up to the max. */
    private static final long DEFAULT_CALL_TIMEOUT_MS = 1_000;
    private static final long MAX_CALL_TIMEOUT_MS = 10_000;
    private static final int MAX_STATE_BYTES = 1_000_000;
    private static final Pattern TIMEOUT_MS = Pattern.compile("[0-9]{1,6}");
    private static final Builds BUILDS = new Builds();
    private static final Pattern PACKAGE_LINE = Pattern.compile("(?m)^\\s*package\\s");

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/build", exchange -> respond(exchange, Server::handleBuild));
        server.createContext("/start", exchange -> respond(exchange, Server::handleStart));
        server.createContext("/decide", exchange -> respond(exchange, Server::handleDecide));
        server.createContext("/close", exchange -> respond(exchange, Server::handleClose));
        // The default executor is one thread, which would make every battle wait
        // on whichever /decide is sitting out its timeout.
        server.setExecutor(java.util.concurrent.Executors.newCachedThreadPool());
        server.start();
        System.out.println("Listening on :8080");
    }

    private interface Handler {
        String handle(HttpExchange exchange) throws Exception;
    }

    /** Always 200, always JSON, always a status. */
    private static void respond(HttpExchange exchange, Handler handler) throws IOException {
        String body;
        try {
            body = handler.handle(exchange);
        } catch (Throwable t) {
            body = reply("runtime_error", "Server error: " + t);
        }
        byte[] resp = body.getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(200, resp.length);
        exchange.getResponseBody().write(resp);
        exchange.close();
    }

    /** POST /build, body Submission.java: compiles it and keeps it for /start. */
    private static String handleBuild(HttpExchange exchange) throws Exception {
        byte[] raw = exchange.getRequestBody().readNBytes(MAX_BODY_BYTES + 1);
        if (raw.length > MAX_BODY_BYTES) {
            return reply("bad_request", "Submission is larger than " + MAX_BODY_BYTES + " bytes",
                    "\"build\":null");
        }
        String source = new String(raw, StandardCharsets.UTF_8);
        if (PACKAGE_LINE.matcher(source).find()) {
            return reply("compile_error",
                    "Remove the package line: Submission must be in the default package.",
                    "\"build\":null");
        }
        Path workDir = Files.createTempDirectory("dsagame-build");
        boolean kept = false;
        try {
            Files.writeString(workDir.resolve("Submission.java"), source);
            copySources(Path.of("api"), workDir);
            copySources(Path.of("runner"), workDir);
            String problems = javac(workDir);
            if (problems == null) {
                problems = teavm(workDir);
            }
            if (problems != null) {
                return reply("compile_error", problems, "\"build\":null");
            }
            String id = BUILDS.add(workDir);
            kept = true;
            return reply("ok", "", "\"build\":" + quote(id));
        } finally {
            if (!kept) {
                deleteTree(workDir);
            }
        }
    }

    /** POST /start?build=&amp;timeout_ms=: a fresh node process and a fresh Submission. */
    private static String handleStart(HttpExchange exchange) throws Exception {
        Map<String, String> query = parseQuery(exchange.getRequestURI().getRawQuery());
        String none = "\"instance\":null,\"console\":\"\",\"error\":null";
        Builds.Build build = BUILDS.get(query.get("build"));
        if (build == null) {
            return reply("unknown_build", "No build " + query.get("build")
                    + "; it was closed, expired or never existed.", none);
        }
        long timeout = DEFAULT_CALL_TIMEOUT_MS;
        String timeoutParam = query.get("timeout_ms");
        if (timeoutParam != null) {
            if (!TIMEOUT_MS.matcher(timeoutParam).matches()
                    || Long.parseLong(timeoutParam) < 1 || Long.parseLong(timeoutParam) > MAX_CALL_TIMEOUT_MS) {
                return reply("bad_request", "timeout_ms must be a whole number from 1 to "
                        + MAX_CALL_TIMEOUT_MS, none);
            }
            timeout = Long.parseLong(timeoutParam);
        }
        Instance instance = BUILDS.start(build, Path.of("runner", "host.js").toAbsolutePath(), timeout);
        String line = instance.call("start");
        return spliceReply(line, "\"instance\":" + quote(instance.id) + ",", none);
    }

    /** POST /decide?instance=, body the state JSON: the student's action for it. */
    private static String handleDecide(HttpExchange exchange) throws Exception {
        Map<String, String> query = parseQuery(exchange.getRequestURI().getRawQuery());
        String none = "\"console\":\"\",\"action\":null,\"error\":null";
        String instanceId = query.get("instance");
        Builds.Build build = BUILDS.forInstance(instanceId);
        Instance instance = build == null ? null : build.instance(instanceId);
        if (instance == null || instance.isDead()) {
            return reply("unknown_instance", "No running battle " + instanceId
                    + "; it ended, was replaced by a later /start, or never existed.", none);
        }
        byte[] raw = exchange.getRequestBody().readNBytes(MAX_STATE_BYTES + 1);
        if (raw.length > MAX_STATE_BYTES) {
            return reply("bad_request", "The state is larger than " + MAX_STATE_BYTES + " bytes", none);
        }
        // One request per line to host.js. A raw line break can only be
        // whitespace between JSON tokens, never inside a string, so this keeps
        // the JSON the same.
        String state = new String(raw, StandardCharsets.UTF_8).replace('\r', ' ').replace('\n', ' ');
        return spliceReply(instance.call("decide\t" + state), "", none);
    }

    /** POST /close?build=: stops its battle and deletes it. */
    private static String handleClose(HttpExchange exchange) throws Exception {
        Map<String, String> query = parseQuery(exchange.getRequestURI().getRawQuery());
        if (!BUILDS.close(query.get("build"))) {
            return reply("unknown_build", "No build " + query.get("build") + ".");
        }
        return reply("ok", "");
    }

    /**
     * Turns one line from host.js into a response: the fields it already has,
     * after status and message. A line from Runner that starts with "internal"
     * means this request was wrong, not the student's code.
     *
     * @param extra fields to put before the line's own, each followed by a comma
     * @param none the fields the response has when there is no line to use
     */
    private static String spliceReply(String line, String extra, String none) {
        if (line == null) {
            return reply("unknown_instance", "That battle has already ended.", none);
        }
        String internal = "{\"internal\":";
        if (line.startsWith(internal)) {
            return "{\"status\":\"bad_request\",\"message\":" + line.substring(internal.length(), line.length() - 1)
                    + "," + none + "}";
        }
        return "{\"status\":\"ok\",\"message\":\"\"," + extra + line.substring(1);
    }

    /** fields is more JSON fields after status and message, without a leading comma, or none. */
    private static String reply(String status, String message, String... fields) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"status\":").append(quote(status));
        sb.append(",\"message\":").append(quote(message));
        for (String field : fields) {
            sb.append(',').append(field);
        }
        sb.append('}');
        return sb.toString();
    }

    /** Copies every .java file under root into workDir, keeping its package directories. */
    private static void copySources(Path root, Path workDir) throws IOException {
        List<Path> sources = javaSources(root);
        for (Path source : sources) {
            Path target = workDir.resolve(root.relativize(source).toString());
            Files.createDirectories(target.getParent());
            Files.copy(source, target, StandardCopyOption.REPLACE_EXISTING);
        }
    }

    private static List<Path> javaSources(Path root) throws IOException {
        List<Path> sources = new ArrayList<>();
        try (DirectoryStream<Path> entries = Files.newDirectoryStream(root)) {
            for (Path entry : entries) {
                if (Files.isDirectory(entry)) {
                    sources.addAll(javaSources(entry));
                } else if (entry.getFileName().toString().endsWith(".java")) {
                    sources.add(entry);
                }
            }
        }
        Collections.sort(sources);
        return sources;
    }

    /** Returns javac's output on failure, or null if everything compiled. */
    private static String javac(Path workDir) throws IOException {
        List<String> args = new ArrayList<>();
        args.add("-d");
        args.add(workDir.toString());
        for (Path source : javaSources(workDir)) {
            args.add(source.toString());
        }
        JavaCompiler compiler = ToolProvider.getSystemJavaCompiler();
        ByteArrayOutputStream javacErr = new ByteArrayOutputStream();
        int result = compiler.run(null, null, javacErr, args.toArray(new String[0]));
        if (result == 0) {
            return null;
        }
        // Strip the temp dir so students see "Submission.java:5: error: ...".
        return javacErr.toString(StandardCharsets.UTF_8)
                .replace(workDir + File.separator, "")
                .replace(workDir.toString(), "");
    }

    /** Returns TeaVM's problems on failure, or null if the build was clean. */
    private static String teavm(Path workDir) throws Exception {
        TeaVMTool tool = new TeaVMTool();
        tool.setMainClass("Runner");
        tool.setTargetType(org.teavm.tooling.TeaVMTargetType.JAVASCRIPT);
        tool.setTargetFileName("classes.js");
        tool.setClassLoader(new java.net.URLClassLoader(
            new java.net.URL[]{ workDir.toUri().toURL() }));
        tool.setTargetDirectory(workDir.resolve("out").toFile());
        tool.generate();

        DefaultProblemTextConsumer consumer = new DefaultProblemTextConsumer();
        StringBuilder problems = new StringBuilder();
        for (var problem : tool.getProblemProvider().getProblems()) {
            problem.render(consumer);
            problems.append(consumer.getText()).append("\n");
        }
        if (problems.length() == 0) {
            return null;
        }
        return "TeaVM build problems:\n" + problems;
    }

    private static Map<String, String> parseQuery(String rawQuery) {
        Map<String, String> params = new HashMap<>();
        if (rawQuery == null) {
            return params;
        }
        for (String pair : rawQuery.split("&")) {
            int eq = pair.indexOf('=');
            if (eq < 0) {
                continue;
            }
            params.put(URLDecoder.decode(pair.substring(0, eq), StandardCharsets.UTF_8),
                    URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8));
        }
        return params;
    }

    static String quote(String s) {
        StringBuilder sb = new StringBuilder();
        sb.append('"');
        if (s != null) {
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                if (c == '"') {
                    sb.append("\\\"");
                } else if (c == '\\') {
                    sb.append("\\\\");
                } else if (c == '\n') {
                    sb.append("\\n");
                } else if (c == '\r') {
                    sb.append("\\r");
                } else if (c == '\t') {
                    sb.append("\\t");
                } else if (c < 0x20 || c == 0x7f) {
                    sb.append(String.format("\\u%04x", (int) c));
                } else {
                    sb.append(c);
                }
            }
        }
        sb.append('"');
        return sb.toString();
    }

    static void deleteTree(Path root) {
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                Files.deleteIfExists(path);
            }
        } catch (IOException e) {
            System.err.println("could not delete " + root + ": " + e);
        }
    }
}
