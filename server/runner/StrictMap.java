import java.util.AbstractMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Set;

/**
 * The Map every JSON object in the state becomes. It keeps the order the keys
 * arrived in, and reading a key it does not have throws, naming the key, so a
 * typo in a student's key fails where it happened instead of as a
 * NullPointerException somewhere later. A key that is present with a null value
 * still reads as null.
 *
 * <p>It wraps a LinkedHashMap rather than extending one: TeaVM's LinkedHashMap
 * calls get from its own methods, so an overridden get that calls containsKey
 * recursed until the stack ran out.
 */
class StrictMap extends AbstractMap<String, Object> {
    private final LinkedHashMap<String, Object> entries = new LinkedHashMap<String, Object>();

    public Object get(Object key) {
        if (!entries.containsKey(key)) {
            throw new NoSuchElementException("the state has no key \"" + key + "\"; it has: " + keyList());
        }
        return entries.get(key);
    }

    public Object getOrDefault(Object key, Object fallback) {
        return entries.containsKey(key) ? entries.get(key) : fallback;
    }

    public boolean containsKey(Object key) {
        return entries.containsKey(key);
    }

    public Object put(String key, Object value) {
        return entries.put(key, value);
    }

    public Object remove(Object key) {
        return entries.remove(key);
    }

    public int size() {
        return entries.size();
    }

    public Set<Map.Entry<String, Object>> entrySet() {
        return entries.entrySet();
    }

    private String keyList() {
        StringBuilder sb = new StringBuilder();
        for (String key : entries.keySet()) {
            if (sb.length() > 0) {
                sb.append(", ");
            }
            sb.append(key);
        }
        return sb.length() == 0 ? "(no keys)" : sb.toString();
    }
}
