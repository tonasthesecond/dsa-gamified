import dsagame.api.Strategy;
import java.util.Map;
import org.teavm.jso.JSBody;

/** Tries to run raw JavaScript in node; must not compile. */
public class Submission implements Strategy {
    @JSBody(script = "return typeof require === 'function' ? 'node ' + process.version : 'no require';")
    private static native String escape();

    public String decide(Map<String, Object> state) {
        return "pass " + escape();
    }
}
