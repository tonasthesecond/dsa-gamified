import dsagame.api.TargetKind;
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

    void intent(int turn, Combatant unit, Intent intent) {
        StringBuilder sb = start(turn, "intent");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        appendMove(sb, intent.move, intent.target);
        finish(sb);
    }

    void action(int turn, Combatant unit, Move move, Combatant target) {
        StringBuilder sb = start(turn, "action");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        appendMove(sb, move, target);
        finish(sb);
    }

    /** The target the attack bounced off, and why. */
    void blocked(int turn, Combatant target, String reason, Move source) {
        StringBuilder sb = start(turn, "blocked");
        sb.append(",\"unit\":").append(Json.quote(target.id));
        sb.append(",\"reason\":").append(Json.quote(reason));
        appendSource(sb, source);
        finish(sb);
    }

    /** hp is the target's hp after the damage. */
    void damage(int turn, Combatant unit, int amount, Move source) {
        StringBuilder sb = start(turn, "damage");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        sb.append(",\"amount\":").append(amount);
        sb.append(",\"hp\":").append(unit.hp);
        appendSource(sb, source);
        finish(sb);
    }

    /** hp is the target's hp after the healing; amount is what it actually got. */
    void heal(int turn, Combatant unit, int amount, Move source) {
        StringBuilder sb = start(turn, "heal");
        sb.append(",\"unit\":").append(Json.quote(unit.id));
        sb.append(",\"amount\":").append(amount);
        sb.append(",\"hp\":").append(unit.hp);
        appendSource(sb, source);
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

    /**
     * The action field is the move's id. A move used on its own user needs no target.
     * move repeats action under the name every move-related event uses.
     */
    private void appendMove(StringBuilder sb, Move move, Combatant target) {
        sb.append(",\"action\":").append(Json.quote(move.id));
        if (move.targetKind != TargetKind.SELF) {
            sb.append(",\"target\":").append(Json.quote(target.id));
        }
        appendSource(sb, move);
    }

    /** Which move an event came from. Left out when it came from no move. */
    private void appendSource(StringBuilder sb, Move source) {
        if (source != null) {
            sb.append(",\"move\":").append(Json.quote(source.id));
        }
    }
}
