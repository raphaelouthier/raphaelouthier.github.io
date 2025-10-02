# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr
	.type	ns_js_fsk_arr, %function
ns_js_fsk_arr:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w4, #1
	ldr x6, =ns_js_fsk_arr_tbl
	add x0, x0, #1
	
	# Main loop.
	
	# Perform reads.
1:
	ldr x2, [x0]
	mov x3, x0

	ubfx x12, x2, #0, #8
	ubfx x13, x2, #8, #8
	ubfx x14, x2, #16, #8
	ubfx x15, x2, #24, #8

	ldrsb w8, [x6, w12, sxtw]
	ldrsb w9, [x6, w13, sxtw]
	ldrsb w10, [x6, w14, sxtw]
	ldrsb w11, [x6, w15, sxtw]

	adds w4, w4, w8
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	add x3, x0, #1
	adds w4, w4, w9
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	add x3, x0, #2
	adds w4, w4, w10
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	add x3, x0, #3
	adds w4, w4, w11
	b.eq 3f;
	cmp x15, #0x22
	b.eq 2f; 

	ubfx x12, x2, #32, #8
	ubfx x13, x2, #40, #8
	ubfx x14, x2, #48, #8
	ubfx x15, x2, #56, #8

	ldrsb w8, [x6, w12, sxtw]
	ldrsb w9, [x6, w13, sxtw]
	ldrsb w10, [x6, w14, sxtw]
	ldrsb w11, [x6, w15, sxtw]

	add x3, x0, #4
	adds w4, w4, w8
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	add x3, x0, #5
	adds w4, w4, w9
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	add x3, x0, #6
	adds w4, w4, w10
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	add x3, x0, #7
	adds w4, w4, w11
	b.eq 3f;
	cmp x15, #0x22
	b.eq 2f; 

	add x0, x0, #8
	b 1b;
	
3:
	add x0, x3, #1
	ldp x29, x30, [sp], #0x10
	ret


	# '"' handling.
2 :
	mov x0, x3
	bl ns_js_fsk_str  
	b 1b;


# Constants.
	.size	ns_js_fsk_arr, .-ns_js_fsk_arr
