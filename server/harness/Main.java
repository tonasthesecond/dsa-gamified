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
        Battle battle = new Battle(units, new Random(scenarioSeed), log);
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

            // 2. Everyone acts in turn order. The student decides for each hero in
            //    turn, seeing what the heroes before it already did; an enemy
            //    carries out what it telegraphed.
            List<Combatant> order = battle.turnOrder();
            for (int i = 0; i < order.size(); i++) {
                Combatant actor = order.get(i);
                if (!actor.isAlive()) {
                    continue;
                }

                String moveId;
                String targetId;
                if (actor.enemy) {
                    moveId = actor.intent.move.id;
                    targetId = actor.intent.target.id;
                } else {
                    Action action;
                    try {
                        action = strategy.decide(battle.snapshot(actor));
                    } catch (Throwable t) {
                        return fail(log, turn, describe("Your decide() for " + actor.name, t));
                    }
                    if (action == null) {
                        return fail(log, turn, "Your decide() returned null for " + actor.name
                                + ". Return Action.pass() if you want to do nothing.");
                    }
                    moveId = action.getMoveId();
                    targetId = action.getTargetId();
                }

                String problem = battle.useError(actor, moveId, targetId);
                if (problem != null) {
                    if (!actor.enemy) {
                        return fail(log, turn, problem);
                    }
                    // An enemy's telegraphed move turned out to be illegal,
                    // usually because its target died first. It still tried.
                    log.action(turn, actor, actor.intent.move, actor.intent.target);
                    continue;
                }
                Move move = actor.findMove(moveId);
                Combatant target = battle.resolveTarget(actor, targetId);

                // 3. Resolve it, unless the level or the move itself says no.
                log.action(turn, actor, move, target);
                String blocked = level.blockReason(target, battle);
                if (blocked == null) {
                    blocked = move.blockReason(battle, actor, target);
                }
                if (blocked != null) {
                    log.blocked(turn, target, blocked);
                } else {
                    move.resolve(battle, actor, target);
                }

                // 4. Win and loss checks. Nothing stops a submission from
                //    attacking its own party, so both sides are checked.
                if (battle.livingEnemies().isEmpty()) {
                    return end(log, turn, true, "All enemies defeated");
                }
                if (battle.heroes().isEmpty()) {
                    return end(log, turn, false, "Party defeated");
                }
            }
        }
        return end(log, level.maxTurns(), false, "Turn limit reached");
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
