import dsagame.api.Action;

/** What an enemy telegraphed it will do this turn: one move, on one target. */
class Intent {
    final Move move;
    final Combatant target;

    Intent(Move move, Combatant target) {
        this.move = move;
        this.target = target;
    }

    /** What the student sees through {@link dsagame.api.Unit#getIntent()}. */
    Action toAction() {
        // Mirrors the sugar in Action, so an attack telegraphs as Type.ATTACK.
        if ("attack".equals(move.id)) {
            return Action.attack(target.shallowSnapshot());
        }
        if ("pass".equals(move.id)) {
            return Action.pass();
        }
        return Action.use(move.snapshot(), target.shallowSnapshot());
    }
}
