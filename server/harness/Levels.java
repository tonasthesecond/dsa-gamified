/** The level registry. One line per level. */
final class Levels {
    private Levels() {
    }

    /** Null for an unknown id. */
    static Level get(String id) {
        if ("smoke".equals(id)) {
            return new SmokeLevel();
        }
        return null;
    }
}
