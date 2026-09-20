import dsagame.api.*;

public class Submission implements Strategy {
    public Action decide(GameState state) {
        // TODO: return Action.attack(someEnemy) instead of passing your turn.
        return Action.pass();
    }
}
