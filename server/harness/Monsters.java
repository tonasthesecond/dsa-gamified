/** The monsters a level can put in its setup. Each call returns a fresh one. */
final class Monsters {
    private Monsters() {
    }

    static Combatant goblin(String id, int maxHp) {
        return new Combatant(id, "Goblin", maxHp, 3, true, Moves.attack());
    }

    /** Drains first, so it keeps itself alive while the party ignores it. */
    static Combatant wraith(String id, int maxHp) {
        return new Combatant(id, "Wraith", maxHp, 2, true, Moves.drain(), Moves.attack());
    }
}
