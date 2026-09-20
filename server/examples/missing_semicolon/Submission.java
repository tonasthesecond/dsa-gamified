import dsagame.api.*;

/** Missing a semicolon on the return, so javac rejects it. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        return Action.pass()
    }
}
