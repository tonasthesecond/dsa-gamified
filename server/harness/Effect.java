/**
 * One step of a move. A move is its effects run in order, so damage, healing
 * and blocking are all just effects, and a new mechanic is a new subclass.
 *
 * <p>An effect changes the battle only through the primitives on
 * {@link Battle}, which log their own events; an effect never builds an event.
 * It holds no battle state, so an instance is safe to reuse from turn to turn.
 */
abstract class Effect {
    /**
     * Carries this step out. The target is already known to be legal.
     *
     * @param state scratch shared with the other effects of this one use of the
     *     move, for passing along what an earlier effect did
     */
    abstract void apply(Battle battle, Combatant user, Combatant target, MoveState state);
}
