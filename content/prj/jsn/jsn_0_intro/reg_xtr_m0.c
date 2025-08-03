/*
 * Parse and return an u64.
 */
u64 ns_js_prs_u64(
	char **jsnp
)
{
	char *jsn = *jsnp;
	uerr err = 0;
	u64 val = 0;
	char *end = (char *) str_to_u64_auto(jsn, &val, &err);
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
 * Parse a range set.
 */
char *ns_js_prs_rng_set(
	char **jsnp
)
{
	char *jsn = *jsnp;

	/* Iterate over each fieldset. */	
	ns_js_arr_fe(jsn) {

		NS_JS_XTR(
			jsn,
			(stt, u64, "start",),
			(wid, u64, "width",)
		);
		info("\t\t\trng :%U:%U\n", stt, wid);

	}
	*jsnp = jsn;
	return 0;

}

/*
 * Parse a field value.
 */
char *ns_js_prs_fld_val(
	char **jsnp
)
{
	char *jsn = *jsnp;

	/* Iterate over each fieldset. */	
	ns_js_arr_fe(jsn) {
		NS_JS_XTR(
			jsn,
			(nam, str_or_nul, "name",),
			(set, rng_set, "rangeset",)
		);
		info("\t\t\tnam :%s\n", nam);

	}
	*jsnp = jsn;
	return 0;

}

/*
 * Parse register fieldset.
 */
char *ns_js_prs_reg_flds(
	char **jsnp
)
{
	char *jsn = *jsnp;

	/* Iterate over each fieldset. */	
	ns_js_arr_fe(jsn) {

		NS_JS_XTR(
			jsn,
			(siz, u64, "width",),
			(val, fld_val, "values",)
		);
		info("\tfieldset :\n");
		info("\t\tsiz :%U\n", siz);

	}
	*jsnp = jsn;
	return 0;

}


/*
 * Parse the ARM64 register database.
 */
char *ns_js_prs_rdb(
	char **jsnp
)
{
	char *jsn = *jsnp;
	/* Iterate over each register. */	
	ns_js_arr_fe(jsn) {

		char *jsnm = (char *) jsn;
		NS_JS_XTR(
			jsnm,
			(flds, reg_flds, "fieldsets",),
			(nam, str, "name",),
			(prp, str_or_nul, "purpose",),
			(ttl, str_or_nul, "title",)
		);
		jsn = jsnm;
		info("%s :\n\t%s\n\t%s\n", nam, ttl, prp);

	}

	*jsnp = jsn;
	return 0;

}

/********
 * Main *
 ********/

/*
 * rdb main.
 */
u32 prc_rdb_main(
	u32 argc,
	char **argv
)
{

	/* Open and map the reg db. */
	ns_res stg_res;
	ns_stg *stg = nsk_stg_opn(&stg_res, "/home/bt/Downloads/armdb/Registers.json");
	assert(stg);
	char *jsn = ns_stg_map(stg, 0, 0, ns_stg_siz(stg), NS_STG_ATT_RED | NS_STG_ATT_WRT);
	assert(jsn);

	/* Parse. */
	ns_js_prs_rdb(&jsn);

	return 0;
	
}

