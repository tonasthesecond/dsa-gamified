import dsagame.api.Strategy;
import java.util.Map;

/** Fails before the battle starts, in its constructor. */
public class Submission implements Strategy {
    public Submission() {
        throw new IllegalStateException("not ready");
    }

    public String decide(Map<String, Object> state) {
        return null;
    }
}
