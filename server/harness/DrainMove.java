import dsagame.api.TargetKind;

/** Hurts one enemy and heals the user by as much as it actually took off. */
class DrainMove extends Move {
    DrainMove(String id, String name, int power) {
        super(id, name, TargetKind.ENEMY, power);
    }

    void resolve(Battle battle, Combatant user, Combatant target) {
        int before = target.hp;
        battle.dealDamage(target, user.attack + power);
        battle.heal(user, before - target.hp);
    }
}
