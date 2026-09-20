import dsagame.api.TargetKind;

/** Hurts one enemy for the user's attack plus this move's power. */
class DamageMove extends Move {
    DamageMove(String id, String name, int power) {
        super(id, name, TargetKind.ENEMY, power);
    }

    void resolve(Battle battle, Combatant user, Combatant target) {
        battle.dealDamage(target, user.attack + power);
    }
}
