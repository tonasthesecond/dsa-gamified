import dsagame.api.Action;
import dsagame.api.MoveInfo;
import dsagame.api.Unit;
import java.util.ArrayList;
import java.util.List;

/**
 * A fighter as the harness sees it: mutable, lives for one scenario.
 * The student only ever sees the immutable {@link Unit} snapshot of it.
 */
class Combatant {
    final String id;
    final String name;
    final int maxHp;
    final int attack;
    final boolean enemy;
    /** This combatant's own move instances, in its own order. */
    final List<Move> moves;
    int hp;
    /** What this combatant telegraphed for this turn. Set by the harness each turn. */
    Intent intent;

    Combatant(String id, String name, int maxHp, int attack, boolean enemy, Move... moves) {
        this.id = id;
        this.name = name;
        this.maxHp = maxHp;
        this.attack = attack;
        this.enemy = enemy;
        this.hp = maxHp;
        this.moves = new ArrayList<Move>();
        for (int i = 0; i < moves.length; i++) {
            this.moves.add(moves[i]);
        }
        // Anyone can always do nothing, so nothing else has to special-case it.
        this.moves.add(new PassMove());
    }

    boolean isAlive() {
        return hp > 0;
    }

    /** Null if this combatant does not know that move. */
    Move findMove(String moveId) {
        for (int i = 0; i < moves.size(); i++) {
            if (moves.get(i).id.equals(moveId)) {
                return moves.get(i);
            }
        }
        return null;
    }

    /** Intents are only shown for enemies; the hero has not decided yet. */
    Unit snapshot() {
        Action intentAction = null;
        if (enemy && intent != null) {
            intentAction = intent.toAction();
        }
        return new Unit(id, name, hp, maxHp, attack, enemy, intentAction, moveInfos());
    }

    /** A snapshot without the intent, used inside an intent so it cannot recurse. */
    Unit shallowSnapshot() {
        return new Unit(id, name, hp, maxHp, attack, enemy, null, moveInfos());
    }

    private List<MoveInfo> moveInfos() {
        List<MoveInfo> infos = new ArrayList<MoveInfo>();
        for (int i = 0; i < moves.size(); i++) {
            infos.add(moves.get(i).snapshot());
        }
        return infos;
    }
}
