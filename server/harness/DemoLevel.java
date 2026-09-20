import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * TEST ONLY. Not a real level and not shown to students.
 *
 * <p>Smoke one step up: a party of two against three monsters, so the tests
 * cover several heroes, several moves and a move that does not deal damage.
 * The goblins' health varies with the seed, so the scenarios differ.
 */
class DemoLevel extends Level {
    String id() {
        return "demo";
    }

    List<Combatant> setup(long seed) {
        Random random = new Random(seed);
        List<Combatant> units = new ArrayList<Combatant>();
        units.add(Heroes.knight("knight"));
        units.add(Heroes.cleric("cleric"));
        for (int i = 0; i < 3; i++) {
            units.add(Monsters.goblin("e" + (i + 1), 12 + random.nextInt(5)));
        }
        return units;
    }
}
