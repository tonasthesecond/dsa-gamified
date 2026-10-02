import dsagame.api.Strategy;

/**
 * The TeaVM main class. It knows nothing about the game: it turns state JSON
 * into Maps, hands them to the student's decide, and sends back the String it
 * returns, a command such as "attack e1", as it is.
 *
 * <p>runner/host.js loads the compiled program once and calls main once per
 * request, so the static instance below lives as long as the node process,
 * which is one battle. Args: &lt;nonce&gt; start, or &lt;nonce&gt; decide
 * &lt;state JSON&gt;.
 *
 * <p>The reply is printed as the nonce followed by one JSON object. The student
 * shares this stdout; the host picks the reply out by the nonce, which is fresh
 * for every call and never visible to student code, so no amount of printing
 * can fake a reply. A decide reply is {"action":...,"error":null} or
 * {"action":null,"error":{"kind":...,"message":...}}; a start reply is the
 * same without "action". When the request itself was wrong rather than the
 * student's code, the reply is {"internal":"..."}, and "internal" is always its
 * first key so the host and the server can tell it apart by prefix alone.
 */
public class Runner {
    private static Strategy instance;

    public static void main(String[] args) {
        String nonce = args[0];
        System.out.println(nonce + reply(args));
    }

    private static String reply(String[] args) {
        String op = args.length > 1 ? args[1] : "";
        if ("start".equals(op)) {
            instance = null;
            try {
                instance = new Submission();
            } catch (Throwable t) {
                return threw("constructor", t, false);
            }
            return "{\"error\":null}";
        }
        if (!"decide".equals(op) || args.length < 3) {
            return internal("unknown request: " + op);
        }
        if (instance == null) {
            return internal("decide before a successful start");
        }

        Object state;
        try {
            state = Json.parse(args[2]);
        } catch (IllegalArgumentException e) {
            return internal("the state is not JSON: " + e.getMessage());
        }
        if (!(state instanceof StrictMap)) {
            return internal("the state is not a JSON object");
        }

        String action;
        try {
            action = instance.decide((StrictMap) state);
        } catch (Throwable t) {
            return threw("decide", t, true);
        }
        if (action == null) {
            return error("returned_null", "decide() returned null", null, true);
        }
        return "{\"action\":" + Json.quote(action) + ",\"error\":null}";
    }

    private static String threw(String where, Throwable t, boolean withAction) {
        String message = t.getMessage();
        return error("threw", message == null ? "" : message,
                "\"exception\":" + Json.quote(t.getClass().getName())
                        + ",\"in\":" + Json.quote(where), withAction);
    }

    /**
     * extra is more fields for the error object, already JSON, or null. A start
     * reply has no action field, a decide reply always has one.
     */
    private static String error(String kind, String message, String extra, boolean withAction) {
        StringBuilder sb = new StringBuilder();
        sb.append(withAction ? "{\"action\":null," : "{");
        sb.append("\"error\":{\"kind\":").append(Json.quote(kind));
        sb.append(",\"message\":").append(Json.quote(message));
        if (extra != null) {
            sb.append(',').append(extra);
        }
        sb.append("}}");
        return sb.toString();
    }

    private static String internal(String message) {
        return "{\"internal\":" + Json.quote(message) + "}";
    }
}
