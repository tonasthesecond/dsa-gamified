import dsagame.api.Strategy;
import java.util.List;
import java.util.Map;

/**
 * Focuses one enemy at a time with the Knight's strongest move, and has the
 * Cleric heal whoever is badly hurt instead of attacking. Wins demo.
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        Map<String, Object> self = (Map<String, Object>) state.get("self");

        if (knows(self, "heal")) {
            Map<String, Object> hurt = mostHurt((List<Map<String, Object>>) state.get("allies"));
            if (hurt != null && (Integer) hurt.get("hp") * 5 < (Integer) hurt.get("maxHp") * 3) {
                return "heal " + hurt.get("id");
            }
        }

        // Everyone piles onto the same enemy, so it stops hitting back sooner.
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");
        return (knows(self, "smite") ? "smite " : "attack ") + enemies.get(0).get("id");
    }

    @SuppressWarnings("unchecked")
    private static boolean knows(Map<String, Object> unit, String moveId) {
        List<Map<String, Object>> moves = (List<Map<String, Object>>) unit.get("moves");
        for (int i = 0; i < moves.size(); i++) {
            if (moves.get(i).get("id").equals(moveId)) {
                return true;
            }
        }
        return false;
    }

    private static Map<String, Object> mostHurt(List<Map<String, Object>> allies) {
        Map<String, Object> worst = null;
        for (int i = 0; i < allies.size(); i++) {
            Map<String, Object> ally = allies.get(i);
            if (worst == null || missing(ally) > missing(worst)) {
                worst = ally;
            }
        }
        return worst;
    }

    private static int missing(Map<String, Object> unit) {
        return (Integer) unit.get("maxHp") - (Integer) unit.get("hp");
    }
}
