import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/** Attacks the first enemy every time. */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        return "attack " + enemies.get(0).get("id");
    }
}
