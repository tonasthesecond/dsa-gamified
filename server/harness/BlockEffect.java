/**
 * A guard: if the move bounces off this target, logs why and stops the rest of
 * the move. Put it first in the move's effects and subclass it for the rule.
 * A rule about a target that every move bounces off belongs in
 * {@link Level#blockReason} instead.
 */
abstract class BlockEffect extends Effect {
    /**
     * Whether this move bounces off this target.
     *
     * @return a reason shown to the player, or null if the move goes through
     */
    abstract String reason(Battle battle, Combatant user, Combatant target);

    final void apply(Battle battle, Combatant user, Combatant target, MoveState state) {
        String reason = reason(battle, user, target);
        if (reason != null) {
            battle.block(target, reason);
            state.halt();
        }
    }
}
