import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * 3. Swarm Nest. A swarm's "body" is an array. Send the index of its smallest
 * value as the crit: "attack e2 | crit 1". The wiring is done; write minIndex().
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        Map<String, Object> target = enemies.get(0);
        Map<String, Object> body = (Map<String, Object>) target.get("body");
        List<Object> values = (List<Object>) body.get("values");
        return "attack " + target.get("id") + " | crit " + minIndex(values);
    }

    /** The index of the smallest value, from 0. Values are distinct whole numbers. */
    static int minIndex(List<Object> values) {
        // TODO: read each value with ((Number) values.get(i)).intValue().
        return 0;
    }
}
