import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * 1. Goblin Camp. decide() runs once for each of your units on its turn.
 * Return a command: the move, then who it hits.
 *   "attack e1"   "heal knight"   "block"   "pass"
 * state.get("self") is the unit deciding; "allies" and "enemies" are lists.
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        return "attack " + enemies.get(0).get("id");
    }
}
