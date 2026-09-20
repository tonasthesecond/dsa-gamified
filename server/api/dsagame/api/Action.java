package dsagame.api;

/** Something a combatant does on its turn. Immutable. */
public final class Action {
    public enum Type { ATTACK, PASS }

    private final Type type;
    private final String targetId;

    private Action(Type type, String targetId) {
        this.type = type;
        this.targetId = targetId;
    }

    /**
     * Attack a unit.
     *
     * @throws IllegalArgumentException if target is null
     */
    public static Action attack(Unit target) {
        if (target == null) {
            throw new IllegalArgumentException("attack target must not be null");
        }
        return new Action(Type.ATTACK, target.getId());
    }

    /** Do nothing this turn. */
    public static Action pass() {
        return new Action(Type.PASS, null);
    }

    public Type getType() {
        return type;
    }

    /** The id of the unit being attacked, or null for a PASS. */
    public String getTargetId() {
        return targetId;
    }
}
