package dsagame.api;

/**
 * An immutable snapshot of one move a unit knows. A {@link MoveInfo} is to a
 * move what a {@link Unit} is to a combatant: a copy you can read, not the
 * thing itself.
 */
public final class MoveInfo {
    private final String id;
    private final String name;
    private final TargetKind targetKind;
    private final int power;

    public MoveInfo(String id, String name, TargetKind targetKind, int power) {
        this.id = id;
        this.name = name;
        this.targetKind = targetKind;
        this.power = power;
    }

    /** The id to use with {@link Action#use}. Stable; the name is not. */
    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    /** Who this move may be used on. Using it on anything else loses the scenario. */
    public TargetKind getTargetKind() {
        return targetKind;
    }

    /** How strong the move is. What that means is up to the move. */
    public int getPower() {
        return power;
    }
}
