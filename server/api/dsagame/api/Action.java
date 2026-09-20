package dsagame.api;

/** Something a combatant does on its turn. Immutable. */
public final class Action {
    public enum Type { ATTACK, PASS, USE }

    private final Type type;
    private final String moveId;
    private final String targetId;

    private Action(Type type, String moveId, String targetId) {
        this.type = type;
        this.moveId = moveId;
        this.targetId = targetId;
    }

    /**
     * Attack a unit.
     *
     * <p>Sugar for using the move with id {@code "attack"}, which every
     * combatant has.
     *
     * @throws IllegalArgumentException if target is null
     */
    public static Action attack(Unit target) {
        if (target == null) {
            throw new IllegalArgumentException("attack target must not be null");
        }
        return new Action(Type.ATTACK, "attack", target.getId());
    }

    /** Do nothing this turn. */
    public static Action pass() {
        return new Action(Type.PASS, "pass", null);
    }

    /**
     * Use one of your moves on a unit.
     *
     * <p>The move must be one of {@link Unit#getMoves()} on the unit acting, and
     * the target must match the move's {@link MoveInfo#getTargetKind()}.
     *
     * @throws IllegalArgumentException if move or target is null
     */
    public static Action use(MoveInfo move, Unit target) {
        if (move == null) {
            throw new IllegalArgumentException("move must not be null");
        }
        if (target == null) {
            throw new IllegalArgumentException("move target must not be null");
        }
        return new Action(Type.USE, move.getId(), target.getId());
    }

    public Type getType() {
        return type;
    }

    /**
     * The id of the move being used: {@code "attack"} for an attack,
     * {@code "pass"} for a pass, the move's own id otherwise.
     */
    public String getMoveId() {
        return moveId;
    }

    /** The id of the unit being attacked, or null for a PASS. */
    public String getTargetId() {
        return targetId;
    }
}
