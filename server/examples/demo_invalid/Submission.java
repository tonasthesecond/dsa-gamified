import dsagame.api.*;
import java.util.List;

/**
 * Borrows a move from an ally instead of taking one of its own: the Knight does
 * not know Heal, so the scenario ends with an error naming both.
 */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        List<Unit> allies = state.getAllies();
        for (int i = 0; i < allies.size(); i++) {
            List<MoveInfo> moves = allies.get(i).getMoves();
            for (int j = 0; j < moves.size(); j++) {
                if (moves.get(j).getId().equals("heal")) {
                    return Action.use(moves.get(j), state.getSelf());
                }
            }
        }
        return Action.pass();
    }
}
