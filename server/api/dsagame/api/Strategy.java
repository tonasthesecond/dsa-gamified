package dsagame.api;

/**
 * The one interface every submission implements.
 *
 * <p>Your class must be called {@code Submission}, must be public, must live in
 * the default package (no {@code package} line), and must have a public no-arg
 * constructor. A fresh {@code Submission} is created for every scenario, so
 * instance fields persist from turn to turn but never leak between scenarios.
 */
public interface Strategy {
    /**
     * Decide what to do on this turn.
     *
     * @param state a snapshot of the battle, taken after the enemies have
     *              telegraphed their intents and before anyone acts
     * @return the action to take; returning null loses the scenario
     */
    Action decide(GameState state);
}
