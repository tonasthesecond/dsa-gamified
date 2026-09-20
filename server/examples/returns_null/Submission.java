import dsagame.api.*;

/** Returns null instead of an action. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        return null;
    }
}
