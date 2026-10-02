import dsagame.api.Strategy;
import java.util.Map;

/** Prints forever, so the output limit has to stop it before the timeout does. */
public class Submission implements Strategy {
    public String decide(Map<String, Object> state) {
        while (true) {
            System.out.println("spam spam spam spam spam spam spam spam spam spam spam spam");
        }
    }
}
