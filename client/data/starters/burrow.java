import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * 2. Worm Burrow. Each worm's "body" is a linked list. Send its middle value
 * as the crit: "attack e1 | crit 4". The wiring is done; write middle().
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        Map<String, Object> target = enemies.get(0);
        Map<String, Object> body = (Map<String, Object>) target.get("body");
        return "attack " + target.get("id") + " | crit " + middle(body);
    }

    /**
     * The value of the middle node, following next from head; with an even
     * length, the second of the two middles.
     *   body = {"head": "n2", "nodes": {"n2": {"value": 4, "next": "n5"}, ...}}
     * The nodes table is not in list order, and next is null at the tail.
     */
    @SuppressWarnings("unchecked")
    static int middle(Map<String, Object> body) {
        Map<String, Object> nodes = (Map<String, Object>) body.get("nodes");
        Object head = body.get("head");
        Map<String, Object> first = (Map<String, Object>) nodes.get(head);
        // TODO: walk the list from head and find the middle node.
        return ((Number) first.get("value")).intValue();
    }
}
