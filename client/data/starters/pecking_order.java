import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * 4. Pecking Order. No answer to send: a hit on the enemy with the least hp
 * lands 50% harder. "enemies" is ordered by speed, not hp. Write weakest().
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        return "attack " + weakest(enemies).get("id");
    }

    /** The living enemy with the least "hp". */
    static Map<String, Object> weakest(List<Map<String, Object>> enemies) {
        // TODO: compare ((Number) enemy.get("hp")).intValue() across all of them.
        return enemies.get(0);
    }
}
