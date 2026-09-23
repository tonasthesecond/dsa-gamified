import dsagame.api.MoveInfo;
import dsagame.api.TargetKind;
import java.util.ArrayList;
import java.util.List;

/**
 * Something a combatant can do on its turn: a name and an ordered list of
 * effects. Heroes and monsters use the same moves; the basic attack is a move
 * like any other.
 *
 * <p>A move holds no battle state, so an instance belongs to exactly one
 * combatant and is safe to reuse from turn to turn. A new move is a new list of
 * existing effects in {@link Moves}; only a new mechanic needs a new
 * {@link Effect}.
 */
final class Move {
    final String id;
    final String name;
    /** Shown to the student; says what the move does in words. */
    final String description;
    final TargetKind targetKind;
    /** How strong the move is. What that means is up to the move. */
    final int power;
    /** Run in order by {@link Battle#use}. Empty for a move that does nothing. */
    final List<Effect> effects;

    Move(String id, String name, String description, TargetKind targetKind, int power,
            Effect... effects) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.targetKind = targetKind;
        this.power = power;
        this.effects = new ArrayList<Effect>();
        for (int i = 0; i < effects.length; i++) {
            this.effects.add(effects[i]);
        }
    }

    MoveInfo snapshot() {
        return new MoveInfo(id, name, description, targetKind, power);
    }
}
