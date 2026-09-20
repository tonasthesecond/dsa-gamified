import java.util.ArrayList;
import java.util.List;

/**
 * TEST ONLY. Not a real level and not shown to students.
 *
 * <p>It exists so the javac -> TeaVM -> node pipeline can be tested end to end
 * without any real level content. Any attack wins on turn 1; passing every turn
 * loses on the turn limit. Its numbers are pinned: the end-to-end tests compare
 * against its exact output.
 */
class SmokeLevel extends Level {
    String id() {
        return "smoke";
    }

    List<Combatant> setup(long seed) {
        List<Combatant> units = new ArrayList<Combatant>();
        units.add(new Combatant("hero", "Hero", 30, 6, false, Moves.attack()));
        units.add(new Combatant("e1", "Slime", 6, 1, true, Moves.attack()));
        return units;
    }

    int maxTurns() {
        return 5;
    }
}
