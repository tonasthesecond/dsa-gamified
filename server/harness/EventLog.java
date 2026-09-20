import dsagame.api.Action;
import java.util.ArrayList;
import java.util.List;

/**
 * The events of one scenario, in order. This is the contract with the Godot
 * client: see docs/protocol.md. New event types and new optional fields are
 * fine; renaming or removing a field is not.
 */
class EventLog {
    private final List<String> events = new ArrayList<String>();

    void spawn(Combatant unit) {
        StringBuilder sb = start(0, "spawn");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        sb.append(",\"name\":").append(Json.quote(unit.name));
        sb.append(",\"team\":").append(Json.quote(unit.enemy ? "enemy" : "hero"));
        sb.append(",\"hp\":").append(unit.hp);
        sb.append(",\"maxHp\":").append(unit.maxHp);
        finish(sb);
    }

    void intent(int turn, Combatant unit, Action action) {
        StringBuilder sb = start(turn, "intent");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        appendAction(sb, action);
        finish(sb);
    }

    void action(int turn, Combatant unit, Action action) {
        StringBuilder sb = start(turn, "action");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        appendAction(sb, action);
        finish(sb);
    }

    /** The target the attack bounced off, and why. */
    void blocked(int turn, Combatant target, String reason) {
        StringBuilder sb = start(turn, "blocked");
        sb.append(",\"unit\":").append(Json.quote(target.id));
        sb.append(",\"reason\":").append(Json.quote(reason));
        finish(sb);
    }

    /** hp is the target's hp after the damage. */
    void damage(int turn, Combatant unit, int amount) {
        StringBuilder sb = start(turn, "damage");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        sb.append(",\"amount\":").append(amount);
        sb.append(",\"hp\":").append(unit.hp);
        finish(sb);
    }

    void death(int turn, Combatant unit) {
        StringBuilder sb = start(turn, "death");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        finish(sb);
    }

    void end(int turn, boolean won, String reason) {
        StringBuilder sb = start(turn, "end");
        sb.append(",\"won\":").append(won);
        sb.append(",\"reason\":").append(Json.quote(reason));
        finish(sb);
    }

    String toJsonArray() {
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (int i = 0; i < events.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(events.get(i));
        }
        sb.append(']');
        return sb.toString();
    }

    private StringBuilder start(int turn, String type) {
        StringBuilder sb = new StringBuilder();
        sb.append("{\"turn\":").append(turn);
        sb.append(",\"type\":").append(Json.quote(type));
        return sb;
    }

    private void finish(StringBuilder sb) {
        sb.append('}');
        events.add(sb.toString());
    }

    private void appendAction(StringBuilder sb, Action action) {
        boolean attack = action.getType() == Action.Type.ATTACK;
        sb.append(",\"action\":").append(Json.quote(attack ? "attack" : "pass"));
        if (action.getTargetId() != null) {
            sb.append(",\"target\":").append(Json.quote(action.getTargetId()));
        }
    }
}
