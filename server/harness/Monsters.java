/** The monsters a level can put in its setup. Each call returns a fresh one. */
final class Monsters {
    private Monsters() {
    }

    static Combatant goblin(String id, int maxHp) {
        return new Combatant(id, "Goblin", maxHp, 3, true, Moves.attack());
    }
}
