#define ITR(pos, v, cnt, qt, op, cl) \
    for (u8 i = 0; i < 8; pos++, i++, v >>= 8) { \
        u8 c = (u8) v; \
        if ((c != qt) && (c != op) && (c != cl)) continue; \
        if (c == qt) { \
            pos = ns_js_fsk_str(pos); \
            goto stt; \
        } else if (c == op) { \
            cnt += 1; \
        } else if (c == cl) { \
            if (!(cnt -= 1)) { \
                return pos + 1; \
            } \
        } \
    }

/*
 * Skip an array.
 */
const char *ns_js_fsk_arr(
    const char *pos
)
{
    check(*pos == '[');
    pos++;
    u32 cnt = 1;
    while (1) {
        stt:;
        uint64_t v = *(uint64_t *) pos;
        uint64_t v1 = *(uint64_t *) (pos + 8);
        ITR(pos, v, cnt, '"', '[', ']');
        ITR(pos, v1, cnt, '"', '[', ']');
    }
}

/*
 * Skip an object.
 */
const char *ns_js_fsk_obj(
    const char *pos
)
{
    check(*pos == '{');
    pos++;
    u32 cnt = 1;
    while (1) {
        stt:;
        uint64_t v = *(uint64_t *) pos;
        uint64_t v1 = *(uint64_t *) (pos + 8);
        ITR(pos, v, cnt, '"', '{', '}', ITR1_CHK);
        ITR(pos, v1, cnt, '"', '{', '}', ITR1_CHK);
    }
}


