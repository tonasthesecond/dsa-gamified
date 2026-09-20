package dsagame.api;

/**
 * An immutable snapshot of one combatant, taken at the moment
 * {@link Strategy#decide} was called. It does not update as the battle goes on.
 */
public final class Unit {
    private final String id;
    private final String name;
    private final int hp;
    private final int maxHp;
    private final int attack;
    private final boolean enemy;
    private final Action intent;

    public Unit(String id, String name, int hp, int maxHp, int attack,
                boolean enemy, Action intent) {
        this.id = id;
        this.name = name;
        this.hp = hp;
        this.maxHp = maxHp;
        this.attack = attack;
        this.enemy = enemy;
        this.intent = intent;
    }

    public String getId() {
        return id;
    }

    public String getName() {
        return name;
    }

    public int getHp() {
        return hp;
    }

    public int getMaxHp() {
        return maxHp;
    }

    public int getAttack() {
        return attack;
    }

    public boolean isEnemy() {
        return enemy;
    }

    public boolean isAlive() {
        return hp > 0;
    }

    /** What this unit will do after you act. Null for units that are not enemies. */
    public Action getIntent() {
        return intent;
    }
}
