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
    private final List<Unit> enemies;

    /** Copies the enemy list, so later changes to the list you passed in do not show up here. */
    public GameState(int turn, Unit self, List<Unit> enemies) {
        this.turn = turn;
        this.self = self;
        this.enemies = new ArrayList<Unit>(enemies);
    }

    /** The turn number. The first turn is 1. */
    public int getTurn() {
        return turn;
    }

    /** Your own unit. */
    public Unit getSelf() {
        return self;
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
}
