
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr
	.type	ns_js_fsk_arr, %function
ns_js_fsk_arr:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w4, #1
	mov w5, #0x22 
	ldr x6, =ns_js_fsk_arr_tbl
	add x0, x0, #1
	cmp x0, #0
	
	# Main loop.
	
1:
	
	# Perform reads.
	ldr x2, [x0]
	mov x1, #0
	mov x3, #1

	# Extract char.
	ubfx x12, x2, #0, #8
	ubfx x13, x2, #8, #8
	ubfx x14, x2, #16, #8
	ubfx x15, x2, #24, #8

	# Read lookup table.
	ldrsb w8, [x6, w12, sxtw]
	ldrsb w9, [x6, w13, sxtw]
	ldrsb w10, [x6, w14, sxtw]
	ldrsb w11, [x6, w15, sxtw]
	

	# Determine if we should get out.
	# If we should not get out, compare if we're in a '"'.
	# If we should now get out, do not move forward.
	add w4, w4, w8
	ccmp w4, #0, #0x4, ne
	ccmp w12, w5, #0x4, ne
	csel x3, xzr, x3, eq
	add x1, x1, x3

	add w4, w4, w9
	ccmp w4, #0, #0x4, ne
	ccmp w13, w5, #0x4, ne
	csel x3, xzr, x3, eq
	add x1, x1, x3

	add w4, w4, w10
	ccmp w4, #0, #0x4, ne
	ccmp w14, w5, #0x4, ne
	csel x3, xzr, x3, eq
	add x1, x1, x3

	add w4, w4, w11
	ccmp w4, #0, #0x4, ne
	ccmp w15, w5, #0x4, ne
	csel x3, xzr, x3, eq
	add x1, x1, x3

	b.eq 2f;

	add x0, x0, #4
	b 1b;

2:	
	ldrb w2, [x0, x1]
	add x0, x0, x1
	add x0, x0, #1
	cmp w2, w5 
	b.eq 3f; 

	ldp x29, x30, [sp], #0x10
	ret


	# '"' handling.
3 :
	bl ns_js_fsk_str  
	b 1b;


# Constants.
	.size	ns_js_fsk_arr, .-ns_js_fsk_arr
