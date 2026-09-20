import dsagame.api.*;

/** Throws a message with a quote and a newline in it, to exercise JSON escaping. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        throw new IllegalStateException("he said \"boom\"\nand then it broke");
    }
}
