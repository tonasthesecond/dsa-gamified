import java.util.ArrayList;
import java.util.List;

/**
 * JSON to Map/List, and String quoting, by hand, because this runs under TeaVM,
 * which has no JSON library and no reflection to build one on.
 *
 * <p>Objects parse to {@link StrictMap}, arrays to ArrayList. A number with no
 * fraction or exponent parses to Integer, or Long if it does not fit; any other
 * number to Double.
 */
final class Json {
    /** How deep parse goes before it gives up on the value. */
    private static final int MAX_DEPTH = 64;

    private final String text;
    private int pos;

    private Json(String text) {
        this.text = text;
    }

    /** @throws IllegalArgumentException if text is not one JSON value */
    static Object parse(String text) {
        Json parser = new Json(text);
        Object value = parser.value(0);
        parser.skipWhitespace();
        if (parser.pos != text.length()) {
            throw parser.error("unexpected text after the value");
        }
        return value;
    }

    /** Null becomes an empty string: under TeaVM even Class.getName can be null. */
    static String quote(String s) {
        StringBuilder sb = new StringBuilder();
        quote(s == null ? "" : s, sb);
        return sb.toString();
    }

    private Object value(int depth) {
        if (depth > MAX_DEPTH) {
            throw error("nested more than " + MAX_DEPTH + " levels deep");
        }
        skipWhitespace();
        if (pos >= text.length()) {
            throw error("unexpected end of input");
        }
        char c = text.charAt(pos);
        if (c == '{') {
            return object(depth);
        }
        if (c == '[') {
            return array(depth);
        }
        if (c == '"') {
            return string();
        }
        if (text.startsWith("true", pos)) {
            pos += 4;
            return Boolean.TRUE;
        }
        if (text.startsWith("false", pos)) {
            pos += 5;
            return Boolean.FALSE;
        }
        if (text.startsWith("null", pos)) {
            pos += 4;
            return null;
        }
        if (c == '-' || (c >= '0' && c <= '9')) {
            return number();
        }
        throw error("unexpected character '" + c + "'");
    }

    private StrictMap object(int depth) {
        StrictMap map = new StrictMap();
        pos++;
        skipWhitespace();
        if (peek() == '}') {
            pos++;
            return map;
        }
        while (true) {
            skipWhitespace();
            if (peek() != '"') {
                throw error("expected a key");
            }
            String key = string();
            skipWhitespace();
            expect(':');
            map.put(key, value(depth + 1));
            skipWhitespace();
            char c = next();
            if (c == '}') {
                return map;
            }
            if (c != ',') {
                throw error("expected ',' or '}'");
            }
        }
    }

    private List<Object> array(int depth) {
        List<Object> list = new ArrayList<Object>();
        pos++;
        skipWhitespace();
        if (peek() == ']') {
            pos++;
            return list;
        }
        while (true) {
            list.add(value(depth + 1));
            skipWhitespace();
            char c = next();
            if (c == ']') {
                return list;
            }
            if (c != ',') {
                throw error("expected ',' or ']'");
            }
        }
    }

    private String string() {
        pos++;
        StringBuilder sb = new StringBuilder();
        while (true) {
            char c = next();
            if (c == '"') {
                return sb.toString();
            }
            if (c != '\\') {
                sb.append(c);
                continue;
            }
            char escape = next();
            if (escape == 'n') {
                sb.append('\n');
            } else if (escape == 't') {
                sb.append('\t');
            } else if (escape == 'r') {
                sb.append('\r');
            } else if (escape == 'b') {
                sb.append('\b');
            } else if (escape == 'f') {
                sb.append('\f');
            } else if (escape == 'u') {
                if (pos + 4 > text.length()) {
                    throw error("unfinished \\u escape");
                }
                sb.append((char) Integer.parseInt(text.substring(pos, pos + 4), 16));
                pos += 4;
            } else if (escape == '"' || escape == '\\' || escape == '/') {
                sb.append(escape);
            } else {
                throw error("unknown escape \\" + escape);
            }
        }
    }

    private Object number() {
        int start = pos;
        boolean whole = true;
        while (pos < text.length()) {
            char c = text.charAt(pos);
            if (c == '.' || c == 'e' || c == 'E') {
                whole = false;
            } else if (!(c == '-' || c == '+' || (c >= '0' && c <= '9'))) {
                break;
            }
            pos++;
        }
        String digits = text.substring(start, pos);
        try {
            if (whole) {
                long value = Long.parseLong(digits);
                if (value >= Integer.MIN_VALUE && value <= Integer.MAX_VALUE) {
                    return Integer.valueOf((int) value);
                }
                return Long.valueOf(value);
            }
            return Double.valueOf(Double.parseDouble(digits));
        } catch (NumberFormatException e) {
            pos = start;
            throw error("bad number " + digits);
        }
    }

    private void skipWhitespace() {
        while (pos < text.length()) {
            char c = text.charAt(pos);
            if (c != ' ' && c != '\n' && c != '\r' && c != '\t') {
                return;
            }
            pos++;
        }
    }

    private char peek() {
        if (pos >= text.length()) {
            throw error("unexpected end of input");
        }
        return text.charAt(pos);
    }

    private char next() {
        char c = peek();
        pos++;
        return c;
    }

    private void expect(char c) {
        if (next() != c) {
            pos--;
            throw error("expected '" + c + "'");
        }
    }

    private IllegalArgumentException error(String what) {
        return new IllegalArgumentException("bad JSON at character " + pos + ": " + what);
    }

    private static void quote(String s, StringBuilder sb) {
        sb.append('"');
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
            } else if (c < 0x20 || c == 0x7f || c == 0x2028 || c == 0x2029) {
                // U+2028 and U+2029 are legal in JSON but end a line in JavaScript.
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
        sb.append('"');
    }
}
