import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * Follows the worm's list from head to find its middle value and sends it as
 * the crit answer, so every attack crits. Answers ride after a "|" in the
 * command, which the service passes through untouched.
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        Map<String, Object> worm = enemies.get(0);
        Map<String, Object> body = (Map<String, Object>) worm.get("body");
        Map<String, Object> nodes = (Map<String, Object>) body.get("nodes");

        // Count the nodes, then walk again to the middle one.
        int length = 0;
        Object at = body.get("head");
        while (at != null) {
            length++;
            at = ((Map<String, Object>) nodes.get(at)).get("next");
        }
        at = body.get("head");
        for (int i = 0; i < length / 2; i++) {
            at = ((Map<String, Object>) nodes.get(at)).get("next");
        }
        Object middle = ((Map<String, Object>) nodes.get(at)).get("value");
        return "attack " + worm.get("id") + " | crit " + middle;
    }
}
