#ifndef NS_LIB_JS_H
#define NS_LIB_JS_H

/************
 * Skip API *
 ************/

/*
 * Skip functions receive the location of the start of a json entity,
 * and if it is valid, they return a pointer to the first character after
 * the said entity.
 * If it is invalid, they return 0.
 */

/*
 * Skip whitespaces.
 * Never fails.
 */
const char *ns_js_skp_whs(
	const char *start
);
#define NS_JS_SKP_WHS(x) ({x = (typeof(x)) ns_js_skp_whs(x); check(x); x;})

/*
 * Skip "true".
 */
const char *ns_js_skp_true(
	const char *start
);

/*
 * Skip "false".
 */
const char *ns_js_skp_false(
	const char *start
);

/*
 * Skip "null".
 */
const char *ns_js_skp_null(
	const char *start
);

/*
 * Skip characters.
 */
const char *ns_js_skp_chars(
	const char *start
);

/*
 * Skip a string.
 */
const char *ns_js_skp_str(
	const char *start
);

/*
 * Skip a integer.
 */
const char *ns_js_skp_int(
	const char *start
);

/*
 * Skip a fraction.
 */
const char *ns_js_skp_frc(
	const char *start
);

/*
 * Skip an exponent.
 */
const char *ns_js_skp_exp(
	const char *start
);

/*
 * Skip a number.
 */
const char *ns_js_skp_nb(
	const char *start
);

/*
 * Skip a member.
 */
const char *ns_js_skp_mmb(
	const char *start
);

/*
 * Skip members.
 */
const char *ns_js_skp_mmbs(
	const char *start
);

/*
 * Skip members until the elment at @key.
 */
const char *ns_js_skp_mmbs_to(
	const char *pos,
	const char *key
);

/*
 * Skip an object.
 */
const char *ns_js_skp_obj(
	const char *start
);

/*
 * Skip an element.
 */
const char *ns_js_skp_elm(
	const char *start
);

/*
 * Skip elements.
 */
const char *ns_js_skp_elms(
	const char *start
);

/*
 * Skip an array.
 */
const char *ns_js_skp_arr(
	const char *start
);

/*
 * Skip a value.
 */
const char *ns_js_skp_val(
	const char *start
);

/*****************
 * Array parsing *
 *****************/

/*
 * Start the parsing of a json array starting at @start.
 * Return the location of the first element if a valid array starts
 * at @start, 0 if no valid array starts at @start.
 * If the returned value is the end of the arra, set @end.
 * If the returned array is a valid element, clear @end.
 */
const char *ns_js_arr_prs_stt(
	const char *start,
	u8 *end
);

/*
 * Return the start of the next element of the currently parsed array.
 * @start is the value returned by either @ns_js_arr_parse_*.
 * If the skip fails, return 0.
 * If the returned value is the end of the array, set @end.
 * If the returned array is a valid element, clear @end.
 */
const char *ns_js_arr_prs_skp(
	const char *start,
	u8 *end
);

/*
 * Return the start of the next element of the currently parsed array.
 * @pos is the value returned by either @ns_js_arr_parse_*.
 * If the skip fails, return 0.
 * If the returned value is the end of the array, set @end.
 * If the returned array is a valid element, clear @end.
 */
const char *ns_js_arr_prs_nxt(
	const char *pos,
	u8 *end
);

/*
 * Finish the parsing of a json array ending at @start.
 * Return the location of the next character after it, if a valid array ends
 * at @start, 0 otherwise.
 */
const char *ns_js_arr_prs_end(
	const char *start
);

/******************
 * Object parsing *
 ******************/

/*
 * Start the parsing of a json object starting at @pos.
 * Return the location of the first element if a valid object starts
 * at @pos, 0 if no valid object starts at @pos.
 * If the returned value is the end of the object, set @end.
 * If the returned object is a valid element, clear @end.
 */
const char *ns_js_obj_prs_stt(
	const char *pos,
	u8 *end
);

/*
 * Return the start of the next element of the currently parsed object.
 * @pos is the value returned by either @ns_js_obj_parse_*.
 * If the skip fails, return 0.
 * If the returned value is the end of the object, set @end.
 * If the returned object is a valid element, clear @end.
 */
const char *ns_js_obj_prs_skp(
	const char *pos,
	u8 *end
);

/*
 * Return the start of the next element of the currently parsed object.
 * @pos is the value returned by either @ns_js_obj_parse_*.
 * If the skip fails, return 0.
 * If the returned value is the end of the object, set @end.
 * If the returned object is a valid element, clear @end.
 */
const char *ns_js_obj_prs_nxt(
	const char *pos,
	u8 *end
);

/*
 * Finish the parsing of a json object ending at @pos.
 * Return the location of the next character after it, if a valid object ends
 * at @pos, 0 otherwise.
 */
const char *ns_js_obj_prs_end(
	const char *pos
);

/*************
 * Iteration *
 *************/
/*
 * Iterate over all elements of a container.
 */
#define ns_js_cnt_fe(typ, idt, jsn) \
for ( \
	char __ns_js_itr_end_##idt = ({jsn = (typeof(jsn)) ns_js_##typ##_prs_stt(jsn, (u8 *) &__ns_js_itr_end_##idt); __ns_js_itr_end_##idt; }); \
	({if (__ns_js_itr_end_##idt) {jsn = (typeof(jsn)) ns_js_##typ##_prs_end(jsn);}; (__ns_js_itr_end_##idt == 0);}); \
	jsn = (typeof(jsn)) ns_js_##typ##_prs_nxt(jsn, (u8 *) &__ns_js_itr_end_##idt) \
)

/*
 * Iterate over all elements of an object.
 */
#define ns_js_obj_fe_(jsn, i) ns_js_cnt_fe(obj, i, jsn)
#define ns_js_obj_fe(jsn) ns_js_cnt_fe(obj, 0, jsn)

/*
 * Iterate over all elements of an array.
 */
#define ns_js_arr_fe_(jsn, i) ns_js_cnt_fe(arr, i, jsn)
#define ns_js_arr_fe(jsn) ns_js_cnt_fe(arr, 0, jsn)

/**************
 * Extraction *
 **************/

#define EXPAND(...) __VA_ARGS__
#define REMOVE(...)

/*
 * Iterate over all members of the
 * objecty starting at @jsn, and parse
 * members that match the list of fields
 * using dedicated extractors, storing them
 * in locally defined variables. 
 */
#define NS_JS_XTR_DEF(nam, prs, str, len, ...) \
	_unused_ typeof(ns_js_prs_##prs(0 NS_PRP_CDN_EMP(__VA_ARGS__)(, __VA_ARGS__))) nam = 0;
#define NS_JS_XTR_PRS(nam, prs, str, len, ...) \
	if ((nam_siz == len NS_PRP_CDT_EMP(len) (sizeof(str) - 1)) && (!strn_cmp(str, nam_stt, len NS_PRP_CDT_EMP(len) (sizeof(str) - 1)))) { \
		nam = ns_js_prs_##prs(&__jsn NS_PRP_CDN_EMP(__VA_ARGS__)(, __VA_ARGS__)); \
		goto __found; \
	}
#define NS_JS_XTR(jsn, ...) \
	\
	/* Define local variables to contain parsing results. */ \
	NS_PRP_CAL(NS_JS_XTR_DEF, EMPTY, __VA_ARGS__) \
	{ \
		typeof(jsn)__jsn = jsn; \
		ns_js_obj_fe_(__jsn, xtr) { \
			\
			/* Skip the name, compute its length. */ \
			check(*__jsn == '"'); \
			const char *nam_stt = __jsn + 1; \
			__jsn = (typeof(__jsn)) ns_js_skp_str(__jsn); \
			const char *nam_end = __jsn - 1; \
			check(nam_end >= nam_stt); \
			const uad nam_siz = psub(nam_end, nam_stt); \
			\
			/* Find the element. */ \
			NS_JS_SKP_WHS(__jsn); \
			check((*__jsn) == ':'); \
			__jsn++; \
			NS_JS_SKP_WHS(__jsn); \
			\
			/* Compare all candidates. If found, jump to __found. */ \
			NS_PRP_CAL(NS_JS_XTR_PRS, EMPTY, __VA_ARGS__) \
			\
			/* If not found, skip the colon and element. */ \
			__jsn = (typeof(__jsn)) ns_js_skp_val(__jsn); \
			\
			/* Once parsed, focus on the next element or stop. */ \
			__found:; \
		} \
		jsn = __jsn; \
	}

#endif /* NS_LIB_JS_H */
