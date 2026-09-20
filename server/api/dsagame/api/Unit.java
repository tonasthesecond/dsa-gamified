package dsagame.api;

import java.util.ArrayList;
import java.util.List;

/**
 * An immutable snapshot of one combatant, taken at the moment
 * {@link Strategy#decide} was called. It does not update as the battle goes on.
 */
public final class Unit {
    private final String id;
    private final String name;
    private final int hp;
    private final int maxHp;
    private final int attack;
    private final boolean enemy;
    private final Action intent;
    private final List<MoveInfo> moves;

    /** A unit with no moves. */
    public Unit(String id, String name, int hp, int maxHp, int attack,
                boolean enemy, Action intent) {
        this(id, name, hp, maxHp, attack, enemy, intent, new ArrayList<MoveInfo>());
    }

    /** Copies the move list. */
    public Unit(String id, String name, int hp, int maxHp, int attack,
                boolean enemy, Action intent, List<MoveInfo> moves) {
        this.id = id;
        this.name = name;
        this.hp = hp;
        this.maxHp = maxHp;
        this.attack = attack;
        this.enemy = enemy;
        this.intent = intent;
        this.moves = new ArrayList<MoveInfo>(moves);
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public int getHp() {
        return hp;
    }

    public int getMaxHp() {
        return maxHp;
    }

    public int getAttack() {
        return attack;
    }

    public boolean isEnemy() {
        return enemy;
    }

    public boolean isAlive() {
        return hp > 0;
    }

    /** What this unit will do after you act. Null for units that are not enemies. */
    public Action getIntent() {
        return intent;
    }

    /**
     * The moves this unit knows, in its own order. Every combatant knows
     * {@code attack} and {@code pass}.
     *
     * <p>You get a fresh mutable list every time you call this, so sorting or
     * reordering it is safe and changes nothing else.
     */
    public List<MoveInfo> getMoves() {
        return new ArrayList<MoveInfo>(moves);
    }
}
