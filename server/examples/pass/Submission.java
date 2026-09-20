import dsagame.api.*;

/** Never acts, so it always runs out the turn limit. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        return Action.pass();
    }
}
