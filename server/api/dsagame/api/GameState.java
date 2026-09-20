package dsagame.api;

import java.util.ArrayList;
import java.util.List;

/**
 * An immutable snapshot of the battle, handed to {@link Strategy#decide}.
 *
 * <p>The public constructor is there so you can build a fake state and unit-test
 * your own {@code decide} locally.
 */
public final class GameState {
    private final int turn;
    private final Unit self;
    private final List<Unit> allies;
    private final List<Unit> enemies;

    /** Copies the enemy list, so later changes to the list you passed in do not show up here. */
    public GameState(int turn, Unit self, List<Unit> enemies) {
        this(turn, self, selfOnly(self), enemies);
    }

    /** Copies both lists, so later changes to the lists you passed in do not show up here. */
    public GameState(int turn, Unit self, List<Unit> allies, List<Unit> enemies) {
        this.turn = turn;
        this.self = self;
        this.allies = new ArrayList<Unit>(allies);
        this.enemies = new ArrayList<Unit>(enemies);
    }

    /** The turn number. The first turn is 1. */
    public int getTurn() {
        return turn;
    }

    /** The unit you are deciding for this call. */
    public Unit getSelf() {
        return self;
    }

    /**
     * Your side of the fight: every living unit on your team, in party order,
     * including the one you are deciding for.
     *
     * <p>You get a fresh mutable list every time you call this, so sorting or
     * reordering it is safe and changes nothing else.
     */
    public List<Unit> getAllies() {
        return new ArrayList<Unit>(allies);
    }

    /**
     * The enemies. The game only ever puts living enemies in here.
     *
     * <p>You get a fresh mutable list every time you call this, so sorting or
     * reordering it is safe and changes nothing else.
     */
    public List<Unit> getEnemies() {
        return new ArrayList<Unit>(enemies);
    }

    private static List<Unit> selfOnly(Unit self) {
        List<Unit> list = new ArrayList<Unit>();
        if (self != null) {
            list.add(self);
        }
        return list;
    }
}
