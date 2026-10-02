import dsagame.api.Strategy;
import java.util.Map;

/** Missing a semicolon on the return, so javac rejects it. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        return null
    }
}
