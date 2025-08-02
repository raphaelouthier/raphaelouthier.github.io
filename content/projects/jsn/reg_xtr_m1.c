/**************
 * Structures *
 **************/

/*
 * Bitfield.
 */
typedef struct {

	/* Bitfields of the same register. */
	ns_dls bfls;

	/* Name. */
	const char *nam;

	/* Start. */
	u8 stt;

	/* Size. */
	u8 siz;

} rdb_bfl;	

/*
 * Register.
 */
typedef struct {

	/* Registers of the same db. */
	ns_mapn_str regs;

	/* Bitfields. */
	ns_dls bfls;

	/* Number of bits. */
	u8 siz;

} rdb_reg;

/*
 * System.
 */
typedef struct {

	/* Registers sorted by name. */
	ns_map_str regs;

} rdb_sys;

/***********
 * Parsers *
 ***********/

/*
 * Parse and return an u8.
 */
u8 ns_js_prs_u8(
	char **jsnp
)
{
	char *jsn = *jsnp;
	uerr err = 0;
	u8 val = 0;
	char *end = (char *) str_to_u8_auto(jsn, &val, &err);
	check(!err);
	*jsnp = end;
	return val;
}

/*
 * Parse and return a string or a 'null'.
 */
char *ns_js_prs_str_or_nul(
	char **jsnp
)
{
	char *jsn = *jsnp;
	if (*jsn == 'n') {
		*jsnp = jsn + 4;
		return 0;
	}
	char *end = (char *) ns_js_skp_str(jsn);
	*(end - 1) = 0;
	*jsnp = end;
	return jsn + 1; 
}

/*
 * Parse a range set, return the covered range.
 */
u16 ns_js_prs_rng_set(
	char **jsnp
)
{
	char *jsn = *jsnp;

	/* Iterate over each bit range, enlarge if needed. */
	u8 stt = 0;
	u8 end = 0;
	u8 mult = 0;
	ns_js_arr_fe(jsn) {

		NS_JS_XTR(
			jsn,
			(_stt, u8, "start",),
			(_siz, u8, "width",)
		);
		u8 _end = _stt + _siz;

		/* Enlarge if needed. */
		if (mult) {
			if (_stt < stt) stt = _stt;
			if (_end > end) end = _end;
		} else {
			stt = _stt;
			end = _end;
		}
		stt = _stt;
		mult = 1;
	}
	*jsnp = jsn;
	return (u16) stt | (u16) (end - stt) << 8;

}

/*
 * Parse a bit field array.
 * Store allocated bitfield descriptors in @dst. 
 */
u8 ns_js_prs_bfl(
	char **jsnp,
	ns_dls *dst
)
{
	char *jsn = *jsnp;

	/* Iterate over each bitfield.
	 * Expect one in practice. */	
	u8 mul = 0;
	ns_js_arr_fe(jsn) {
		assert(!mul, "multi fieldset register.\n");
		NS_JS_XTR(
			jsn,
			(nam, str_or_nul, "name",),
			(set, rng_set, "rangeset",)
		);
		if (nam) {
			ns_alloc__(rdb_bfl, bfl);
			ns_dls_ib(dst, &bfl->bfls);
			bfl->nam = nam;
			bfl->stt = (u8) (set & 0xff);
			bfl->siz = (u8) ((set >> 8) & 0xff);
		}
	}
	*jsnp = jsn;
	return 0;

}

/*
 * Parse a register layout array expectedly containing
 * only one layout.
 * Store bitfields in @dst.
 * Return the register size.
 */
u8 ns_js_prs_reg_lyts(
	char **jsnp,
	ns_dls *dst
)
{
	char *jsn = *jsnp;

	/* Iterate over each fieldset. */	
	u8 siz = 0;
	u8 mult = 0;
	ns_js_arr_fe(jsn) {
		assert(!mult, "multi-layout register.\n");

		NS_JS_XTR(
			jsn,
			(_siz, u8, "width",),
			(_val, bfl, "values",,dst)
		);
		siz = _siz;

	}
	*jsnp = jsn;
	return siz;

}

/*
 * Parse the ARM64 register database.
 * Store register content in @sys.
 */
char *ns_js_prs_rdb(
	char **jsnp,
	rdb_sys *sys
)
{
	char *jsn = *jsnp;
	/* Iterate over each register. */	
	ns_js_arr_fe(jsn) {


		/* Parse the register descriptor,
		 * store bitfields in a local list. */
		ns_dls_def(bfls);
		NS_JS_XTR(
			jsn,
			(siz, reg_lyts, "fieldsets",,bfls),
			(nam, str, "name",),
			(prp, str_or_nul, "purpose",),
			(ttl, str_or_nul, "title",)
		);
		assert(nam, "unnamed register.\n");
		
		/* Create a register descriptor,
		 * save the name, transfer bitfields. */
		ns_alloc__(rdb_reg, reg);
		uerr err = ns_map_str_put(&sys->regs, &reg->regs, nam);
		if (err) {
			//debug("duplicate register '%s'.\n", nam); // There are a few of those...
			rdb_bfl *bfl;
			ns_dls_fes(bfl, bfls, bfls) {
				ns_free_(bfl);
			}
			ns_dls_init(bfls);
			ns_free_(reg);
		} else {
			ns_dls_rp(bfls, &reg->bfls);
			reg->siz = siz;
		}

		/* Ensure nothing dangling. */
		ns_dls_del(bfls);

	}

	*jsnp = jsn;
	return 0;

}
