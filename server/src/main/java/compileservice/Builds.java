package compileservice;

import java.io.IOException;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Compiled submissions waiting to be run, keyed by build id, and the one node
 * process each may have running. A build lives until /close, or until nobody
 * has touched it for {@link #IDLE_MILLIS}, so a client that crashes mid-battle
 * leaves nothing behind for long.
 */
final class Builds {
    static final long IDLE_MILLIS = 60_000;

    private static final SecureRandom RANDOM = new SecureRandom();

    private final Map<String, Build> builds = new ConcurrentHashMap<>();
    /** Instance id to the build it belongs to. */
    private final Map<String, Build> byInstance = new ConcurrentHashMap<>();

    Builds() {
        ScheduledExecutorService janitor = Executors.newSingleThreadScheduledExecutor(r -> {
            Thread t = new Thread(r, "builds-janitor");
            t.setDaemon(true);
            return t;
        });
        janitor.scheduleAtFixedRate(this::expire, 10, 10, TimeUnit.SECONDS);
    }

    /** Takes ownership of workDir, which holds out/classes.js. */
    String add(Path workDir) {
        String id = "b" + randomHex();
        builds.put(id, new Build(id, workDir));
        return id;
    }

    /** Null if there is no such build. */
    Build get(String id) {
        Build build = id == null ? null : builds.get(id);
        if (build != null) {
            build.touch();
        }
        return build;
    }

    /** The build an instance belongs to, or null. */
    Build forInstance(String instanceId) {
        Build build = instanceId == null ? null : byInstance.get(instanceId);
        if (build != null) {
            build.touch();
        }
        return build;
    }

    /** Stops the build's instance, if any, and starts a fresh one in its place. */
    Instance start(Build build, Path hostJs, long timeoutMillis) throws IOException {
        synchronized (build) {
            stopInstance(build);
            Instance instance = Instance.start("i" + randomHex(),
                    build.workDir.resolve("out").resolve("classes.js"), hostJs, timeoutMillis);
            build.instance = instance;
            byInstance.put(instance.id, build);
            return instance;
        }
    }

    /** False if there was no such build. */
    boolean close(String id) {
        Build build = id == null ? null : builds.remove(id);
        if (build == null) {
            return false;
        }
        synchronized (build) {
            stopInstance(build);
            Server.deleteTree(build.workDir);
        }
        return true;
    }

    private void stopInstance(Build build) {
        if (build.instance != null) {
            byInstance.remove(build.instance.id);
            build.instance.kill();
            build.instance = null;
        }
    }

    private void expire() {
        long now = System.currentTimeMillis();
        List<String> idle = new ArrayList<>();
        for (Build build : builds.values()) {
            if (now - build.lastUsed > IDLE_MILLIS) {
                idle.add(build.id);
            }
        }
        for (String id : idle) {
            close(id);
        }
    }

    private static String randomHex() {
        byte[] bytes = new byte[12];
        RANDOM.nextBytes(bytes);
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(Character.forDigit((b >> 4) & 0xf, 16)).append(Character.forDigit(b & 0xf, 16));
        }
        return sb.toString();
    }

    static final class Build {
        final String id;
        final Path workDir;
        /** The running battle, or null. Guarded by this. */
        Instance instance;
        private volatile long lastUsed = System.currentTimeMillis();

        Build(String id, Path workDir) {
            this.id = id;
            this.workDir = workDir;
        }

        void touch() {
            lastUsed = System.currentTimeMillis();
        }

        /** The instance with this id, if it is still this build's current one. */
        synchronized Instance instance(String instanceId) {
            return instance != null && instance.id.equals(instanceId) ? instance : null;
        }
    }
}
