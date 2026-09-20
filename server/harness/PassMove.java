import dsagame.api.TargetKind;

/**
 * Do nothing. Every combatant gets one, so passing needs no special case
 * anywhere in the battle loop.
 */
class PassMove extends Move {
    PassMove() {
        super("pass", "Pass", TargetKind.SELF, 0);
    }

    void resolve(Battle battle, Combatant user, Combatant target) {
        // Doing nothing is the point.
    }
}
