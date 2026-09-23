/**
 * Hurts the target for the user's attack plus this effect's power, and adds
 * what actually landed to {@link MoveState#DAMAGE}.
 */
class DamageEffect extends Effect {
    private final int power;

    DamageEffect(int power) {
        this.power = power;
    }

    void apply(Battle battle, Combatant user, Combatant target, MoveState state) {
        state.add(MoveState.DAMAGE, battle.dealDamage(target, user.attack + power));
    }
}
