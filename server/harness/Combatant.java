import dsagame.api.Action;
import dsagame.api.Unit;

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
    int hp;
    /** What this combatant telegraphed for this turn. Set by the harness each turn. */
    Action intent;

    Combatant(String id, String name, int maxHp, int attack, boolean enemy) {
        this.id = id;
        this.name = name;
        this.maxHp = maxHp;
        this.attack = attack;
        this.enemy = enemy;
        this.hp = maxHp;
    }

    boolean isAlive() {
        return hp > 0;
    }

    /** Intents are only shown for enemies; the hero has not decided yet. */
    Unit snapshot() {
        return new Unit(id, name, hp, maxHp, attack, enemy, enemy ? intent : null);
    }
}
