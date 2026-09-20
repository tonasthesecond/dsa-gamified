import dsagame.api.GameState;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/** The mutable state of one scenario in progress. */
class Battle {
    final Combatant hero;
    /** Hero first, then the enemies, in setup order. Dead ones stay in the list. */
    final List<Combatant> combatants;
    /** Seeded from the scenario seed, so a level that wants randomness stays deterministic. */
    final Random random;
    int turn;

    Battle(List<Combatant> combatants, Random random) {
        this.combatants = combatants;
        this.hero = combatants.get(0);
        this.random = random;
        this.turn = 0;
    }

    List<Combatant> livingEnemies() {
        List<Combatant> living = new ArrayList<Combatant>();
        for (int i = 0; i < combatants.size(); i++) {
            Combatant c = combatants.get(i);
            if (c.enemy && c.isAlive()) {
                living.add(c);
            }
        }
        return living;
    }

    /** Null if no combatant has that id. */
    Combatant find(String id) {
        if (id == null) {
            return null;
        }
        for (int i = 0; i < combatants.size(); i++) {
            if (id.equals(combatants.get(i).id)) {
                return combatants.get(i);
            }
        }
        return null;
    }

    /** What the student sees this turn: living enemies only. */
    GameState snapshot() {
        List<Combatant> living = livingEnemies();
        List<dsagame.api.Unit> enemies = new ArrayList<dsagame.api.Unit>();
        for (int i = 0; i < living.size(); i++) {
            enemies.add(living.get(i).snapshot());
        }
        return new GameState(turn, hero.snapshot(), enemies);
    }
}
