import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Harness checks that do not need the server: a seed has to give the same battle
 * every time, and different seeds have to give different battles.
 *
 * <p>Uses its own level rather than smoke, because smoke is deliberately fixed.
 */
public class HarnessTest {
    public static void main(String[] args) {
        String first = Main.run(new SeededLevel(), 42L);
        String second = Main.run(new SeededLevel(), 42L);
        String other = Main.run(new SeededLevel(), 99L);

        check("same seed gives byte-identical output", first.equals(second));
        check("different seeds give different scenarios", !first.equals(other));

        String demo = Main.run(Levels.get("demo"), 3L);
        String demoAgain = Main.run(Levels.get("demo"), 3L);
        String demoOther = Main.run(Levels.get("demo"), 4L);

        check("demo: same seed gives byte-identical output", demo.equals(demoAgain));
        check("demo: different seeds give different scenarios", !demo.equals(demoOther));
        System.out.println("harness tests passed");
    }

    private static void check(String what, boolean ok) {
        if (!ok) {
            System.out.println("FAIL: " + what);
            System.exit(1);
        }
        System.out.println("ok: " + what);
    }

    /** TEST ONLY. Not registered in Levels; its enemy varies with the seed. */
    static class SeededLevel extends Level {
        String id() {
            return "seeded";
        }

        List<Combatant> setup(long seed) {
            Random random = new Random(seed);
            List<Combatant> units = new ArrayList<Combatant>();
            units.add(new Combatant("hero", "Hero", 30, 3, false));
            units.add(new Combatant("e1", "Mob", 5 + random.nextInt(20), 1, true));
            return units;
        }
    }
}
