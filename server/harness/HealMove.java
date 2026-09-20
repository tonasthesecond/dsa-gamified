import dsagame.api.TargetKind;

/** Heals one ally, or the user, by this move's power. */
class HealMove extends Move {
    HealMove(String id, String name, int power) {
        super(id, name, TargetKind.ALLY, power);
    }

    void resolve(Battle battle, Combatant user, Combatant target) {
        battle.heal(target, power);
    }
}
