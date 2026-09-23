/**
 * Heals someone: the target by a fixed amount, or the user by a number an
 * earlier effect of the same move left in its {@link MoveState}.
 */
class HealEffect extends Effect {
    private final boolean onUser;
    private final int power;
    /** Null for a fixed amount. */
    private final String fromState;

    private HealEffect(boolean onUser, int power, String fromState) {
        this.onUser = onUser;
        this.power = power;
        this.fromState = fromState;
    }

    /** Heals one ally, or the user, by this power. */
    static HealEffect target(int power) {
        return new HealEffect(false, power, null);
    }

    /** Heals the user by what an earlier effect wrote under this key, such as {@link MoveState#DAMAGE}. */
    static HealEffect userFromState(String key) {
        return new HealEffect(true, 0, key);
    }

    void apply(Battle battle, Combatant user, Combatant target, MoveState state) {
        int amount = fromState == null ? power : state.get(fromState);
        battle.heal(onUser ? user : target, amount);
    }
}
