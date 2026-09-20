/**
 * The only JSON we need. Built by hand with StringBuilder because this code runs
 * under TeaVM, which has no JSON library.
 */
final class Json {
    private Json() {
    }

    /** Quotes and escapes a string. Null becomes an empty string, not the literal null. */
    static String quote(String s) {
        StringBuilder sb = new StringBuilder();
        sb.append('"');
        if (s != null) {
            for (int i = 0; i < s.length(); i++) {
                char c = s.charAt(i);
                if (c == '"') {
                    sb.append("\\\"");
                } else if (c == '\\') {
                    sb.append("\\\\");
                } else if (c == '\n') {
                    sb.append("\\n");
                } else if (c == '\r') {
                    sb.append("\\r");
                } else if (c == '\t') {
                    sb.append("\\t");
                } else if (c < 0x20 || c == 0x7f) {
                    sb.append("\\u");
                    String hex = Integer.toHexString(c);
                    for (int pad = hex.length(); pad < 4; pad++) {
                        sb.append('0');
                    }
                    sb.append(hex);
                } else {
                    sb.append(c);
                }
            }
        }
        sb.append('"');
        return sb.toString();
    }
}
