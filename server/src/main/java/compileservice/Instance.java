package compileservice;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;

/**
 * One node process running one compiled submission for one battle: a fresh
 * Submission, whose instance fields last until the process does. Talks to
 * runner/host.js one line each way per call.
 */
final class Instance {
    /** What the reader thread queues when node's stdout closes. */
    private static final String EOF = "\u0000eof";

    final String id;
    private final Process process;
    private final Writer toNode;
    private final BlockingQueue<String> fromNode = new LinkedBlockingQueue<>();
    private final long timeoutMillis;
    private boolean dead;

    private Instance(String id, Process process, long timeoutMillis) {
        this.id = id;
        this.process = process;
        this.timeoutMillis = timeoutMillis;
        this.toNode = new OutputStreamWriter(process.getOutputStream(), StandardCharsets.UTF_8);
        // readLine blocks and has no timeout, so it gets its own thread and
        // call() waits on the queue with one.
        Thread reader = new Thread(() -> {
            try (BufferedReader in = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                while ((line = in.readLine()) != null) {
                    fromNode.add(line);
                }
            } catch (IOException ignored) {
                // The process is gone; EOF below says so.
            }
            fromNode.add(EOF);
        }, "instance-" + id);
        reader.setDaemon(true);
        reader.start();
    }

    static Instance start(String id, Path classesJs, Path hostJs, long timeoutMillis) throws IOException {
        ProcessBuilder pb = new ProcessBuilder(
                "node", "--max-old-space-size=" + Server.NODE_HEAP_MB, hostJs.toString(), classesJs.toString());
        // host.js writes only replies to stdout; anything on stderr is node itself
        // failing, which the reply already reports as crashed.
        pb.redirectError(ProcessBuilder.Redirect.DISCARD);
        return new Instance(id, pb.start(), timeoutMillis);
    }

    /**
     * Sends one request and waits for its reply.
     *
     * @return the reply line, a JSON object starting with "console"; or, if the
     *     process timed out or died, a JSON object in the same shape saying so.
     *     After either of those the instance is dead.
     */
    synchronized String call(String request) {
        if (dead) {
            return null;
        }
        boolean decide = !request.equals("start");
        try {
            toNode.write(request);
            toNode.write('\n');
            toNode.flush();
        } catch (IOException e) {
            return fail("crashed", "the Java process stopped before it could be asked", decide);
        }
        String line;
        try {
            line = fromNode.poll(timeoutMillis, TimeUnit.MILLISECONDS);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return fail("crashed", "the server was interrupted", decide);
        }
        if (line == null) {
            return fail("timeout", "did not return within " + timeoutMillis
                    + " ms; is there an infinite loop?", decide);
        }
        if (line.equals(EOF)) {
            return fail("crashed", "the Java process stopped without answering", decide);
        }
        // After an output_limit or crashed reply host.js exits, so a further call
        // finds EOF at once instead of waiting out the timeout.
        return line;
    }

    synchronized boolean isDead() {
        return dead;
    }

    synchronized void kill() {
        dead = true;
        process.destroyForcibly();
    }

    /** Shaped like host.js's replies: a decide reply has "action", a start reply does not. */
    private String fail(String kind, String message, boolean decide) {
        kill();
        return "{\"console\":\"\"," + (decide ? "\"action\":null," : "")
                + "\"error\":{\"kind\":" + Server.quote(kind)
                + ",\"message\":" + Server.quote(message) + "}}";
    }
}
