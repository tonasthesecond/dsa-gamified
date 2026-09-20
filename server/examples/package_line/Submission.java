package foo;

import dsagame.api.*;

/** Has a package line, which the service rejects before javac ever sees it. */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        return Action.pass();
    }
}
