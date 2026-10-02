import dsagame.api.Strategy;
import java.util.Map;

/** Counts its calls in a field and sends the count back, to show fields last for one battle. */
public class Submission implements Strategy {
    private int calls;

    public String decide(Map<String, Object> state) {
        calls++;
        return "pass " + calls;
    }
}
