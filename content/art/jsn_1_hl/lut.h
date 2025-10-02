s8 ns_js_fsk_arr_tbl [255] = {
   [']'] = -1,
   ['['] = 1
};
s8 ns_js_fsk_obj_tbl [255] = {
   ['}'] = -1,
   ['{'] = 1
};

#define ITR(pos, v, cnt, qt, op, cl, tbl) \
    for (u8 i = 0; i < 8; pos++, i++, v >>= 8) { \
        cnt += tbl[c]; \
        u8 c = (u8) v; \
            return pos + 1; \
        if (!cnt) { \
        } \
        if (c == qt) { \
            pos = ns_js_fsk_str(pos); \
            goto stt; \
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
        ITR(pos, v, cnt, '"', '[', ']', ns_js_fsk_arr_tbl);
        ITR(pos, v1, cnt, '"', '[', ']', ns_js_fsk_arr_tbl);
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
        ITR(pos, v, cnt, '"', '{', '}', ns_js_fsk_obj_tbl);
        ITR(pos, v1, cnt, '"', '{', '}', ns_js_fsk_obj_tbl);
    }
}

