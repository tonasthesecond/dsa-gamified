import dsagame.api.Strategy;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * 5. Gatehouse. Every attack needs the median of every value in every enemy
 * body, or it bounces: "attack e1 | median 21.5". Bodies change after a crit,
 * so compute it every turn. Write median(); add crits from earlier levels if
 * you like: "attack e1 | crit 4 | median 21.5".
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        List<Integer> all = new ArrayList<>();
        for (Map<String, Object> enemy : enemies) {
            all.addAll(values((Map<String, Object>) enemy.get("body")));
        }
        return "attack " + enemies.get(0).get("id") + " | median " + median(all);
    }

    /** The middle value once sorted; with an even count, the mean of the two middles. */
    static double median(List<Integer> all) {
        // TODO: sort a copy and pick the middle.
        return all.get(0);
    }

    /** Every value in a body: an "array" body's values, or a "linked_list" body's nodes. */
    @SuppressWarnings("unchecked")
    static List<Integer> values(Map<String, Object> body) {
        List<Integer> found = new ArrayList<>();
        if (body.get("kind").equals("array")) {
            for (Object value : (List<Object>) body.get("values")) {
                found.add(((Number) value).intValue());
            }
        } else {
            for (Object node : ((Map<String, Object>) body.get("nodes")).values()) {
                found.add(((Number) ((Map<String, Object>) node).get("value")).intValue());
            }
        }
        return found;
    }
}
