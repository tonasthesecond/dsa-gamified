import dsagame.api.*;
import java.util.List;

/**
 * Heals an enemy instead of an ally: the Cleric's Heal only works on allies, so
 * the scenario ends with an error naming the Cleric, the move and the target.
 */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        Unit enemy = state.getEnemies().get(0);
        List<MoveInfo> moves = state.getSelf().getMoves();
        for (int i = 0; i < moves.size(); i++) {
            if (moves.get(i).getId().equals("heal")) {
                return Action.use(moves.get(i), enemy);
            }
        }
        return Action.attack(enemy);
    }
}
