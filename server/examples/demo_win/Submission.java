import dsagame.api.*;
import java.util.List;

/**
 * Focuses one goblin at a time with the Knight's strongest move, and has the
 * Cleric heal whoever is badly hurt instead of attacking. Wins demo.
 */
public class Submission implements Strategy {
    public Action decide(GameState state) {
        Unit self = state.getSelf();

        MoveInfo heal = findMove(self, "heal");
        if (heal != null) {
            Unit hurt = mostHurtAlly(state.getAllies());
            if (hurt != null && hurt.getHp() * 5 < hurt.getMaxHp() * 3) {
                return Action.use(heal, hurt);
            }
        }

        // Everyone piles onto the same enemy, so goblins stop hitting back sooner.
        Unit target = state.getEnemies().get(0);
        MoveInfo smite = findMove(self, "smite");
        if (smite != null) {
            return Action.use(smite, target);
        }
        return Action.attack(target);
    }

    private static MoveInfo findMove(Unit unit, String id) {
        List<MoveInfo> moves = unit.getMoves();
        for (int i = 0; i < moves.size(); i++) {
            if (moves.get(i).getId().equals(id)) {
                return moves.get(i);
            }
        }
        return null;
    }

    private static Unit mostHurtAlly(List<Unit> allies) {
        Unit worst = null;
        for (int i = 0; i < allies.size(); i++) {
            Unit ally = allies.get(i);
            if (worst == null || ally.getMaxHp() - ally.getHp() > worst.getMaxHp() - worst.getHp()) {
                worst = ally;
            }
        }
        return worst;
    }
}
