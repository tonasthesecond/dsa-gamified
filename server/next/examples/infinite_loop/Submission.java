import dsagame.api.Strategy;
import java.util.Map;

/** Hangs, so the call has to be killed on the timeout. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        while (true) {
        }
    }
}
