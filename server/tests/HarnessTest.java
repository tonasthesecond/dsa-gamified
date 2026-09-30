import dsagame.api.TargetKind;
import java.util.List;
import java.util.Random;
import java.util.ArrayList;

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

        String guarded = Main.run(new GuardedLevel(), 1L);
        check("a BlockEffect logs blocked, naming the move", guarded.contains(
                "{\"turn\":1,\"type\":\"blocked\",\"unit\":\"hero\",\"reason\":\"Too healthy to hit.\","
                + "\"move\":\"guarded\"}"));
        check("a BlockEffect stops the rest of the move",
                !guarded.contains("\"type\":\"damage\",\"unit\":\"hero\""));
        check("guarded: same seed gives byte-identical output",
                guarded.equals(Main.run(new GuardedLevel(), 1L)));
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
        @Override
        String id() {
            return "seeded";
        }

        @Override
        List<Combatant> setup(long seed) {
            Random random = new Random(seed);
            List<Combatant> units = new ArrayList<Combatant>();
            units.add(new Combatant("hero", "Hero", 30, 3, false));
            units.add(new Combatant("e1", "Mob", 5 + random.nextInt(20), 1, true));
            return units;
        }
    }

    /**
     * TEST ONLY. Not registered in Levels. The enemy's one move bounces off any
     * target above 20 health, and the hero never drops that low.
     */
    static class GuardedLevel extends Level {
        String id() {
            return "guarded";
        }

        List<Combatant> setup(long seed) {
            Move guarded = new Move("guarded", "Guarded", "", TargetKind.ENEMY, 0,
                    new TooHealthy(), new DamageEffect(0));
            List<Combatant> units = new ArrayList<Combatant>();
            units.add(new Combatant("hero", "Hero", 30, 3, false, Moves.attack()));
            units.add(new Combatant("e1", "Mob", 50, 1, true, guarded));
            return units;
        }
    }

    /** TEST ONLY. Blocks the move while its target is above 20 health. */
    static class TooHealthy extends BlockEffect {
        String reason(Battle battle, Combatant user, Combatant target) {
            return target.hp > 20 ? "Too healthy to hit." : null;
        }
    }
}
