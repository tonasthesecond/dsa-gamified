import java.util.ArrayList;
import java.util.List;

/**
 * TEST ONLY. Not a real level and not shown to students.
 *
 * <p>It exists so the javac -> TeaVM -> node pipeline can be tested end to end
 * without any real level content. Any attack wins on turn 1; passing every turn
 * loses on the turn limit.
 */
class SmokeLevel extends Level {
    String id() {
        return "smoke";
    }

    List<Combatant> setup(long seed) {
        List<Combatant> units = new ArrayList<Combatant>();
        units.add(new Combatant("hero", "Hero", 30, 6, false));
        units.add(new Combatant("e1", "Slime", 6, 1, true));
        return units;
    }

    int maxTurns() {
        return 5;
    }
}
