import dsagame.api.Strategy;
import java.util.Map;

/** Misspells a key, which throws naming it instead of quietly returning null. */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        Map<String, Object> self = (Map<String, Object>) state.get("self");
        int hp = (Integer) self.get("hpp");
        return null;
    }
}
