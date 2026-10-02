import dsagame.api.Strategy;
import java.util.Map;

/** Returns null instead of a command. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        return null;
    }
}
