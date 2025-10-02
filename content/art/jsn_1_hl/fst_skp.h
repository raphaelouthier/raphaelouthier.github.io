/*****************
 * Fast skip API *
 *****************/

/*
 * Skip a string.
 */
const char *ns_js_fsk_str(
    const char *pos
)
{
    char c = *(pos++);
    check(c == '"');
    char p = c;
    while (1) {
        c = *(pos++);
        if ((c == '"') && (p != '\\'))
            return pos;
        p = c;
    }
}

/*
 * Skip a number.
 */
const char *ns_js_fsk_nb(
    const char *pos
)
{
    return NS_STR_SKP64(pos, '+', (RNG, '0', '9'), (VAL, 'e'), (VAL, 'E'), (VAL, '.'), (VAL, '+'), (VAL, '-'));
}

/*
 * Skip an array.
 */
const char *ns_js_fsk_arr(
    const char *pos
)
{
    char c = *(pos++);
    check(c == '[');
    u32 cnt = 1;
    while (1) {
        while (((c = *(pos++)) != '[') && (c != ']') && (c != '"'));
        if (c == '"') {
            pos = ns_js_fsk_str(pos - 1);
        } else if (c == '[') {
            cnt += 1;
        } else {
            if (!(cnt -= 1)) {
                return pos;
            }
        }
    }
}

/*
 * Skip an object.
 */
const char *ns_js_fsk_obj(
    const char *pos
)
{
    char c = *(pos++);
    check(c == '{');
    u32 cnt = 1;
    while (1) {
        while (((c = *(pos++)) != '{') && (c != '}') && (c != '"'));
        if (c == '"') {
            pos = ns_js_skp_str(pos - 1);
        } else if (c == '{') {
            cnt += 1;
        } else if (c == '}') {
            if (!(cnt -= 1)) {
                return pos;
            }
        }
    }
}

/*
 * Skip a value.
 */
const char *ns_js_fsk_val(
    const char *pos
)
{
    const char c = *pos;
    if (c == '{') return ns_js_fsk_obj(pos);
    else if (c == '[') return ns_js_fsk_arr(pos);
    else if (c == '"') return ns_js_fsk_str(pos);
    else if (c == 't') return ns_js_fsk_true(pos);
    else if (c == 'f') return ns_js_fsk_false(pos);
    else if (c == 'n') return ns_js_fsk_null(pos);
    else return ns_js_fsk_nb(pos);
}
