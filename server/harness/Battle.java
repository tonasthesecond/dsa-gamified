import dsagame.api.GameState;
import dsagame.api.TargetKind;
import dsagame.api.Unit;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/** The mutable state of one scenario in progress. */
class Battle {
    /** Heroes first, then the enemies, in setup order. Dead ones stay in the list. */
    final List<Combatant> combatants;
    /** Seeded from the scenario seed, so a level that wants randomness stays deterministic. */
    final Random random;
    final EventLog log;
    int turn;
    /** The move {@link #use} is resolving, so the primitives can say where an event came from. */
    private Move resolving;

    Battle(List<Combatant> combatants, Random random, EventLog log) {
        this.combatants = combatants;
        this.random = random;
        this.log = log;
        this.turn = 0;
    }

    /** Living heroes, in party order. */
    List<Combatant> heroes() {
        return living(false);
    }

    /** Living enemies, in spawn order. */
    List<Combatant> livingEnemies() {
        return living(true);
    }

    /**
     * Who acts this turn and in what order: the party first, then the enemies.
     * The one place turn order lives. Anyone who dies before their turn comes up
     * is skipped by the caller.
     */
    List<Combatant> turnOrder() {
        List<Combatant> order = heroes();
        order.addAll(livingEnemies());
        return order;
    }

    /** Living combatants on the same side as this one, including it. */
    List<Combatant> alliesOf(Combatant combatant) {
        return living(combatant.enemy);
    }

    /** Living combatants on the other side. */
    List<Combatant> opponentsOf(Combatant combatant) {
        return living(!combatant.enemy);
    }

    /** The first living hero, or null if the party is wiped out. */
    Combatant firstLivingHero() {
        List<Combatant> heroes = heroes();
        return heroes.isEmpty() ? null : heroes.get(0);
    }

    /** Null if no combatant has that id. */
    Combatant find(String id) {
        if (id == null) {
            return null;
        }
        for (int i = 0; i < combatants.size(); i++) {
            if (id.equals(combatants.get(i).id)) {
                return combatants.get(i);
            }
        }
        return null;
    }

    /** A null target id means the combatant itself, which is what a pass does. */
    Combatant resolveTarget(Combatant user, String targetId) {
        return targetId == null ? user : find(targetId);
    }

    /**
     * Whether this combatant may use this move on this target. The one place a
     * move and a target are checked against each other.
     *
     * @return a message naming the combatant and the move, or null if it is legal
     */
    String useError(Combatant user, String moveId, String targetId) {
        Move move = user.findMove(moveId);
        if (move == null) {
            return user.name + " tried to use \"" + moveId + "\", which it does not know.";
        }
        Combatant target = resolveTarget(user, targetId);
        if (target == null) {
            return user.name + " tried to use " + move.name + " on \"" + targetId
                    + "\", which is not in this battle.";
        }
        String what = user.name + " tried to use " + move.name + " on " + target.name + ", ";
        if (!target.isAlive()) {
            return what + "which is already dead.";
        }
        if (move.targetKind == TargetKind.ENEMY && target.enemy == user.enemy) {
            return what + "which is not an enemy.";
        }
        if (move.targetKind == TargetKind.ALLY && target.enemy != user.enemy) {
            return what + "which is not an ally.";
        }
        if (move.targetKind == TargetKind.SELF && target != user) {
            return what + "but that move only works on itself.";
        }
        return null;
    }

    /** What the student sees this turn, from one hero's point of view. */
    GameState snapshot(Combatant self) {
        List<Unit> allies = snapshots(alliesOf(self));
        List<Unit> enemies = snapshots(opponentsOf(self));
        Unit selfUnit = null;
        for (int i = 0; i < allies.size(); i++) {
            if (allies.get(i).getId().equals(self.id)) {
                selfUnit = allies.get(i);
            }
        }
        return new GameState(turn, selfUnit, allies, enemies);
    }

    /**
     * Carries out a move {@link #useError} has already allowed: its effects in
     * order, sharing one fresh {@link MoveState}, until one of them halts it.
     * The one place a move is resolved.
     *
     * @param blockedBy why the level says every move bounces off this target,
     *     or null if it does not
     */
    void use(Move move, Combatant user, Combatant target, String blockedBy) {
        resolving = move;
        try {
            if (blockedBy != null) {
                block(target, blockedBy);
                return;
            }
            MoveState state = new MoveState();
            for (int i = 0; i < move.effects.size() && !state.halted(); i++) {
                move.effects.get(i).apply(this, user, target, state);
            }
        } finally {
            resolving = null;
        }
    }

    /**
     * Hurts a combatant and logs it. One of the primitives effects are built from.
     *
     * @return the health it actually took off, less than amount if the target
     *     had less left
     */
    int dealDamage(Combatant target, int amount) {
        if (amount < 0) {
            amount = 0;
        }
        int before = target.hp;
        target.hp -= amount;
        if (target.hp < 0) {
            target.hp = 0;
        }
        log.damage(turn, target, amount, resolving);
        if (!target.isAlive()) {
            log.death(turn, target);
        }
        return before - target.hp;
    }

    /**
     * Heals a combatant, never past its maximum, and logs how much it got.
     *
     * @return how much it got
     */
    int heal(Combatant target, int amount) {
        if (amount < 0) {
            amount = 0;
        }
        int healed = Math.min(amount, target.maxHp - target.hp);
        target.hp += healed;
        log.heal(turn, target, healed, resolving);
        return healed;
    }

    /** Logs that a move had no effect on this target, and why. */
    void block(Combatant target, String reason) {
        log.blocked(turn, target, reason, resolving);
    }

    private List<Combatant> living(boolean enemy) {
        List<Combatant> result = new ArrayList<Combatant>();
        for (int i = 0; i < combatants.size(); i++) {
            Combatant c = combatants.get(i);
            if (c.enemy == enemy && c.isAlive()) {
                result.add(c);
            }
        }
        return result;
    }

    private List<Unit> snapshots(List<Combatant> group) {
        List<Unit> units = new ArrayList<Unit>();
        for (int i = 0; i < group.size(); i++) {
            units.add(group.get(i).snapshot());
        }
        return units;
    }
}
