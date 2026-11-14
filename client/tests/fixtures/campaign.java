import dsagame.api.Strategy;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * Wins every campaign level: the cleric heals anyone under half hp; everyone
 * else attacks the enemy with the least hp, with its crit and the median rule
 * answered. Same as _campaign_student "lowest" in smoke_battle.gd.
 */
public class Submission implements Strategy {
    @SuppressWarnings("unchecked")
    public String decide(Map<String, Object> state) {
        Map<String, Object> me = (Map<String, Object>) state.get("self");
        List<Map<String, Object>> allies = (List<Map<String, Object>>) state.get("allies");
        List<Map<String, Object>> enemies = (List<Map<String, Object>>) state.get("enemies");

        if (knows(me, "heal")) {
            List<Map<String, Object>> party = new ArrayList<>(allies);
            party.add(me);
            for (Map<String, Object> ally : party) {
                if (num(ally, "hp") * 2 < num(ally, "maxHp")) {
                    return "heal " + ally.get("id");
                }
            }
        }

        Map<String, Object> target = enemies.get(0);
        for (Map<String, Object> enemy : enemies) {
            if (num(enemy, "hp") < num(target, "hp")) {
                target = enemy;
            }
        }
        String command = "attack " + target.get("id");

        Map<String, Object> crit = (Map<String, Object>) target.get("crit");
        if (crit != null) {
            List<Integer> found = values((Map<String, Object>) target.get("body"));
            if (crit.get("id").equals("middle")) {
                command += " | crit " + found.get(found.size() / 2);
            } else {
                command += " | crit " + found.indexOf(Collections.min(found));
            }
        }

        for (Map<String, Object> rule : (List<Map<String, Object>>) state.get("rules")) {
            if (rule.get("id").equals("median")) {
                List<Integer> all = new ArrayList<>();
                for (Map<String, Object> enemy : enemies) {
                    all.addAll(values((Map<String, Object>) enemy.get("body")));
                }
                Collections.sort(all);
                int half = all.size() / 2;
                double median = all.size() % 2 == 1 ? all.get(half) : (all.get(half - 1) + all.get(half)) / 2.0;
                command += " | median " + median;
            }
        }
        return command;
    }

    /** An array's values, or a linked list's from head along next. */
    @SuppressWarnings("unchecked")
    private static List<Integer> values(Map<String, Object> body) {
        List<Integer> found = new ArrayList<>();
        if (body.get("kind").equals("array")) {
            for (Object value : (List<Object>) body.get("values")) {
                found.add(((Number) value).intValue());
            }
            return found;
        }
        Map<String, Object> nodes = (Map<String, Object>) body.get("nodes");
        Object at = body.get("head");
        while (at != null) {
            Map<String, Object> node = (Map<String, Object>) nodes.get(at);
            found.add(((Number) node.get("value")).intValue());
            at = node.get("next");
        }
        return found;
    }

    @SuppressWarnings("unchecked")
    private static boolean knows(Map<String, Object> unit, String moveId) {
        for (Map<String, Object> move : (List<Map<String, Object>>) unit.get("moves")) {
            if (move.get("id").equals(moveId)) {
                return true;
            }
        }
        return false;
    }

    private static int num(Map<String, Object> unit, String key) {
        return ((Number) unit.get(key)).intValue();
    }
}
