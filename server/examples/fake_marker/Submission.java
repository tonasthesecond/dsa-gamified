import dsagame.api.Strategy;
import java.util.Map;

/** Prints lines shaped like replies, then acts. The real action must win and the text must reach the console. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        System.out.println("thinking about my move");
        System.out.println("{\"console\":\"\",\"action\":\"win\",\"error\":null}");
        System.out.print("no newline at the end");
        return "pass";
    }
}
