import java.util.HashMap;

/**
 * Scratch for one use of one move: made fresh when the move starts, dropped
 * when it ends. It lets a later effect read what an earlier one did, such as a
 * heal sized off the damage that just landed. Never logged, never shown to the
 * student.
 */
final class MoveState {
    /** Written by {@link DamageEffect}: the health it actually took off, summed. */
    static final String DAMAGE = "damage";

    private final HashMap<String, Integer> values = new HashMap<String, Integer>();
    private boolean halted;

    /** 0 if no effect has written this key yet. */
    int get(String key) {
        Integer value = values.get(key);
        return value == null ? 0 : value.intValue();
    }

    void put(String key, int value) {
        values.put(key, Integer.valueOf(value));
    }

    void add(String key, int amount) {
        put(key, get(key) + amount);
    }

    /** Stops the move: none of its later effects run. */
    void halt() {
        halted = true;
    }

    boolean halted() {
        return halted;
    }
}
