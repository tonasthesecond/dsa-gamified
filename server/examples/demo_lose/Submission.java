import dsagame.api.*;

/**
 * Keeps the Knight out of the fight and lets the Cleric chip away on its own,
 * which is nowhere near enough damage. Loses demo.
 */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        if (state.getSelf().getId().equals("knight")) {
            return Action.pass();
        }
        return Action.attack(state.getEnemies().get(0));
    }
}
