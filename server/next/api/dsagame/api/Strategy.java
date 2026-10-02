package dsagame.api;

import java.util.Map;

/**
 * The one interface every submission implements.
 *
 * <p>Your class must be called {@code Submission}, must be public, must live in
 * the default package (no {@code package} line), and must have a public no-arg
 * constructor. A fresh {@code Submission} is created for every battle, so
 * instance fields persist from one call to the next within a battle but never
 * leak into the next one.
 *
 * <p>The state is plain JSON-like data: a {@code Map} has {@code String} keys,
 * and every value is a {@code Map}, a {@code List}, a {@code String}, a
 * {@code Number}, a {@code Boolean} or {@code null}. A whole number arrives as
 * an {@code Integer} (a {@code Long} if it does not fit), any other number as a
 * {@code Double}.
 */
public interface Strategy {
    /**
     * Decide what one of your units does now.
     *
     * <p>Reading a key the state does not have throws an exception that names
     * the key, instead of returning null. Use {@code containsKey} to check for
     * a key that may be missing.
     *
     * @param state the battle as the game describes it to you
     * @return a command: the move's id, then the id of each target, separated
     *     by spaces, such as {@code "attack e1"}, {@code "cleave e1 e2"} or
     *     {@code "block"}; returning null loses the battle
     */
    String decide(Map<String, Object> state);
}
