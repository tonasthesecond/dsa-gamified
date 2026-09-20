package compileservice;

import com.sun.net.httpserver.*;
import org.teavm.tooling.TeaVMTool;
import org.teavm.diagnostics.DefaultProblemTextConsumer;
import java.net.InetSocketAddress;
import javax.tools.*;
import java.io.*;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.regex.Pattern;

/**
 * POST /compile?level=&lt;id&gt;&amp;student=&lt;id&gt; with the raw source of
 * Submission.java as the body. Compiles it with the harness, cross-compiles to
 * JavaScript with TeaVM, runs it under node, and returns the battle log.
 *
 * <p>Always answers 200 with the same envelope; see docs/protocol.md.
 */
public class Server {
    private static final int MAX_BODY_BYTES = 50_000;
    private static final long MAX_OUTPUT_BYTES = 2_000_000L;
    private static final int MAX_CONSOLE_CHARS = 4_000;
    private static final int TIMEOUT_SECONDS = 5;
    private static final String MARKER = "@@DSAGAME_RESULT@@";
    /** Interpolated into the node command line, so this check is a security boundary. */
    private static final Pattern LEVEL_ID = Pattern.compile("[a-z0-9_]{1,40}");
    private static final Pattern PACKAGE_LINE = Pattern.compile("(?m)^\\s*package\\s");

    public static void main(String[] args) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(8080), 0);
        server.createContext("/compile", Server::handleCompile);
        server.start();
        System.out.println("Listening on :8080");
    }

    private static void handleCompile(HttpExchange exchange) throws IOException {
        String body;
        try {
            body = handle(exchange);
        } catch (Throwable t) {
            body = envelope("runtime_error", "Server error: " + t, "", null);
        }
        byte[] resp = body.getBytes(StandardCharsets.UTF_8);
        // Scope this to the client's origin once there is somewhere to deploy to.
        exchange.getResponseHeaders().add("Access-Control-Allow-Origin", "*");
        exchange.getResponseHeaders().add("Content-Type", "application/json");
        exchange.sendResponseHeaders(200, resp.length);
        exchange.getResponseBody().write(resp);
        exchange.close();
    }

    private static String handle(HttpExchange exchange) throws Exception {
        Map<String, String> query = parseQuery(exchange.getRequestURI().getRawQuery());
        String level = query.get("level");
        if (level == null || !LEVEL_ID.matcher(level).matches()) {
            return envelope("bad_request",
                    "level must match [a-z0-9_]{1,40}", "", null);
        }
        String student = query.get("student");
        if (student == null) {
            student = "anonymous";
        }
        long seed = (student + ":" + level).hashCode() & 0x7fffffffL;

        byte[] raw = exchange.getRequestBody().readNBytes(MAX_BODY_BYTES + 1);
        if (raw.length > MAX_BODY_BYTES) {
            return envelope("bad_request",
                    "Submission is larger than " + MAX_BODY_BYTES + " bytes", "", null);
        }
        String source = new String(raw, StandardCharsets.UTF_8);

        // Caught here rather than by javac, where it shows up as "cannot find symbol".
        if (PACKAGE_LINE.matcher(source).find()) {
            return envelope("compile_error",
                    "Remove the package line: Submission must be in the default package.",
                    "", null);
        }
        return run(source, level, seed);
    }

    private static String run(String source, String level, long seed) throws Exception {
        Path workDir = Files.createTempDirectory("submission");
        try {
            Files.writeString(workDir.resolve("Submission.java"), source);
            copySources(Path.of("api"), workDir);
            copySources(Path.of("harness"), workDir);

            String javacOutput = javac(workDir);
            if (javacOutput != null) {
                return envelope("compile_error", javacOutput, "", null);
            }
            String teavmProblems = teavm(workDir);
            if (teavmProblems != null) {
                return envelope("compile_error", teavmProblems, "", null);
            }
            return node(workDir, level, seed);
        } finally {
            deleteTree(workDir);
        }
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
        tool.setMainClass("Main");
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

    private static String node(Path workDir, String level, long seed) throws Exception {
        Path jsFile = workDir.resolve("out").resolve("classes.js");
        Path outputFile = workDir.resolve("output.txt");
        ProcessBuilder pb = new ProcessBuilder(
            "node", "--max-old-space-size=256", "-e",
            "require('" + jsFile + "').main(['" + level + "','" + seed + "'], function(err) { " +
            "if (err) { console.error(err); process.exit(1); } });"
        );
        // A pipe fills at about 64 KB and blocks node, which looks exactly like a
        // timeout. Event logs get bigger than that, so redirect to a file.
        pb.redirectErrorStream(true);
        pb.redirectOutput(outputFile.toFile());
        Process proc = pb.start();
        boolean finished = proc.waitFor(TIMEOUT_SECONDS, java.util.concurrent.TimeUnit.SECONDS);
        if (!finished) {
            proc.destroyForcibly();
            return envelope("timeout",
                    "Execution timed out (5s) — likely an infinite loop", "", null);
        }
        if (Files.size(outputFile) > MAX_OUTPUT_BYTES) {
            return envelope("runtime_error",
                    "Your code printed more than " + MAX_OUTPUT_BYTES + " bytes", "", null);
        }
        String output = Files.readString(outputFile, StandardCharsets.UTF_8);
        if (proc.exitValue() != 0) {
            return envelope("runtime_error",
                    "node exited " + proc.exitValue() + ":\n" + output, "", null);
        }

        // The last marker line wins: the harness prints last, so a student who
        // prints a fake marker line cannot override it.
        String result = null;
        StringBuilder console = new StringBuilder();
        for (String line : output.split("\n", -1)) {
            if (line.startsWith(MARKER)) {
                if (result != null) {
                    console.append(result).append('\n');
                }
                result = line;
            } else {
                console.append(line).append('\n');
            }
        }
        if (result == null) {
            return envelope("runtime_error", "No result line in output:\n" + output, "", null);
        }
        return envelope("ok", "", console.toString(), result.substring(MARKER.length()));
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

    /** resultJson is raw JSON from the harness, or null. */
    private static String envelope(String status, String message, String console, String resultJson) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"status\":").append(quote(status));
        sb.append(",\"message\":").append(quote(message));
        sb.append(",\"console\":").append(quote(trimConsole(console)));
        sb.append(",\"result\":").append(resultJson == null ? "null" : resultJson);
        sb.append('}');
        return sb.toString();
    }

    private static String trimConsole(String console) {
        String trimmed = console.trim();
        if (trimmed.length() <= MAX_CONSOLE_CHARS) {
            return trimmed;
        }
        return trimmed.substring(0, MAX_CONSOLE_CHARS) + "\n... [output truncated]";
    }

    private static String quote(String s) {
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

    private static void deleteTree(Path root) {
        try (var paths = Files.walk(root)) {
            for (Path path : paths.sorted(Comparator.reverseOrder()).toList()) {
                Files.deleteIfExists(path);
            }
        } catch (IOException e) {
            System.err.println("could not delete " + root + ": " + e);
        }
    }
}
