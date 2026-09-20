package dsagame.api;

/** Who a move may be used on. */
public enum TargetKind {
    /** A living unit on the other team. */
    ENEMY,
    /** A living unit on your own team. You count as one of your own allies. */
    ALLY,
    /** The unit using the move, and nobody else. */
    SELF
}
