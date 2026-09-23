import dsagame.api.*;

/** Attacks the first enemy every turn. Wins the smoke level. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        return Action.attack(state.getEnemies().get(0));
    }
}
