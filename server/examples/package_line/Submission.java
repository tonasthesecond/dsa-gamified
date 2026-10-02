package foo;

import dsagame.api.Strategy;
import java.util.Map;

/** Has a package line, which the service rejects before javac ever sees it. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        return null;
    }
}
