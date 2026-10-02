import dsagame.api.Strategy;
import java.util.Map;

/** Throws a message with a quote and a newline in it, to exercise JSON escaping. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        throw new IllegalStateException("he said \"boom\"\nand then it broke");
    }
}
