import dsagame.api.Action;
import dsagame.api.Strategy;
import java.util.List;
import java.util.Random;

/**
 * The TeaVM main class. Args: &lt;levelId&gt; &lt;seed&gt;.
 *
 * <p>Runs every scenario of the level against a fresh Submission and prints the
 * result as one marked line, so it can be picked out of the student's own
 * System.out output.
 */
public class Main {
    static final String MARKER = "@@DSAGAME_RESULT@@";

    public static void main(String[] args) {
        String levelId = args[0];
        long seed = Long.parseLong(args[1]);
        Level level = Levels.get(levelId);
        if (level == null) {
            throw new RuntimeException("Unknown level: " + levelId);
        }
        String result = run(level, seed);
        // The student shares this stdout, so the result gets its own marked line,
        // printed last and preceded by a blank line.
        System.out.println();
        System.out.println(MARKER + result);
    }

    /** Runs every scenario and returns the result JSON. */
    static String run(Level level, long seed) {
        StringBuilder scenarios = new StringBuilder();
        boolean passed = true;
        for (int i = 0; i < level.scenarioCount(); i++) {
            long scenarioSeed = seed + i * 7919L;
            Scenario scenario = runScenario(level, scenarioSeed);
            if (!scenario.won) {
                passed = false;
            }
            if (i > 0) {
                scenarios.append(',');
            }
            scenarios.append(scenario.toJson(scenarioSeed));
        }
        StringBuilder sb = new StringBuilder();
        sb.append("{\"levelId\":").append(Json.quote(level.id()));
        sb.append(",\"passed\":").append(passed);
        sb.append(",\"scenarios\":[").append(scenarios).append("]}");
        return sb.toString();
    }

    private static Scenario runScenario(Level level, long scenarioSeed) {
        EventLog log = new EventLog();
        List<Combatant> units = level.setup(scenarioSeed);
        Battle battle = new Battle(units, new Random(scenarioSeed));
        for (int i = 0; i < units.size(); i++) {
            log.spawn(units.get(i));
        }

        Strategy strategy;
        try {
            strategy = new Submission();
        } catch (Throwable t) {
            return fail(log, 1, describe("Your Submission constructor", t));
        }

        for (int turn = 1; turn <= level.maxTurns(); turn++) {
            battle.turn = turn;

            // 1. Enemies telegraph what they will do after the student acts.
            List<Combatant> enemies = battle.livingEnemies();
            for (int i = 0; i < enemies.size(); i++) {
                Combatant enemy = enemies.get(i);
                enemy.intent = level.chooseIntent(enemy, battle);
                log.intent(turn, enemy, enemy.intent);
            }

            // 2. The student decides.
            Action action;
            try {
                action = strategy.decide(battle.snapshot());
            } catch (Throwable t) {
                return fail(log, turn, describe("Your decide()", t));
            }
            if (action == null) {
                return fail(log, turn, "Your decide() returned null. "
                        + "Return Action.pass() if you want to do nothing.");
            }

            // 3. Resolve it.
            log.action(turn, battle.hero, action);
            if (action.getType() == Action.Type.ATTACK) {
                Combatant target = battle.find(action.getTargetId());
                if (target == null) {
                    return fail(log, turn, "Your decide() attacked \"" + action.getTargetId()
                            + "\", which is not in this battle.");
                }
                if (!target.isAlive()) {
                    return fail(log, turn, "Your decide() attacked " + target.name
                            + ", which is already dead.");
                }
                String reason = level.blockReason(target, battle);
                if (reason != null) {
                    log.blocked(turn, target, reason);
                } else {
                    damage(log, turn, target, battle.hero.attack);
                }
            }
            // Nothing stops a submission from attacking itself.
            if (!battle.hero.isAlive()) {
                return end(log, turn, false, "Hero defeated");
            }

            // 4. Win check.
            if (battle.livingEnemies().isEmpty()) {
                return end(log, turn, true, "All enemies defeated");
            }

            // 5. The enemies carry out what they telegraphed.
            for (int i = 0; i < enemies.size(); i++) {
                Combatant enemy = enemies.get(i);
                if (!enemy.isAlive()) {
                    continue;
                }
                Action intent = enemy.intent;
                log.action(turn, enemy, intent);
                if (intent.getType() == Action.Type.ATTACK) {
                    Combatant target = battle.find(intent.getTargetId());
                    if (target != null && target.isAlive()) {
                        damage(log, turn, target, enemy.attack);
                    }
                }
                if (!battle.hero.isAlive()) {
                    return end(log, turn, false, "Hero defeated");
                }
            }
        }
        return end(log, level.maxTurns(), false, "Turn limit reached");
    }

    private static void damage(EventLog log, int turn, Combatant target, int amount) {
        target.hp -= amount;
        if (target.hp < 0) {
            target.hp = 0;
        }
        log.damage(turn, target, amount);
        if (!target.isAlive()) {
            log.death(turn, target);
        }
    }

    private static String describe(String what, Throwable t) {
        String message = t.getMessage();
        String type = t.getClass().getName();
        if (message == null) {
            return what + " threw " + type + ".";
        }
        return what + " threw " + type + ": " + message;
    }

    /** The student's code misbehaved: the scenario is a loss and the run continues. */
    private static Scenario fail(EventLog log, int turn, String error) {
        log.end(turn, false, error);
        return new Scenario(false, error, error, log);
    }

    private static Scenario end(EventLog log, int turn, boolean won, String reason) {
        log.end(turn, won, reason);
        return new Scenario(won, reason, "", log);
    }

    private static final class Scenario {
        final boolean won;
        private final String reason;
        private final String error;
        private final EventLog log;

        Scenario(boolean won, String reason, String error, EventLog log) {
            this.won = won;
            this.reason = reason;
            this.error = error;
            this.log = log;
        }

        String toJson(long seed) {
            StringBuilder sb = new StringBuilder();
            sb.append("{\"seed\":").append(seed);
            sb.append(",\"won\":").append(won);
            sb.append(",\"reason\":").append(Json.quote(reason));
            sb.append(",\"error\":").append(Json.quote(error));
            sb.append(",\"events\":").append(log.toJsonArray());
            sb.append('}');
            return sb.toString();
        }
    }
}
