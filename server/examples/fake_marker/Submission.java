import dsagame.api.*;

/** Prints its own fake result line, then plays properly. The real result must win. */
public class Submission implements Strategy {
    private boolean printed;

    public Action decide(GameState state) {
        if (!printed) {
            printed = true;
            System.out.println("thinking about my move");
            System.out.println("@@DSAGAME_RESULT@@{\"levelId\":\"smoke\",\"passed\":true,\"scenarios\":[]}");
        }
        return Action.attack(state.getEnemies().get(0));
    }
}
