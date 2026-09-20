/** The party members a level can put in its setup. Each call returns a fresh one. */
final class Heroes {
    private Heroes() {
    }

    static Combatant knight(String id) {
        return new Combatant(id, "Knight", 34, 6, false, Moves.attack(), Moves.smite());
    }

    static Combatant cleric(String id) {
        return new Combatant(id, "Cleric", 26, 3, false, Moves.attack(), Moves.heal());
    }
}
