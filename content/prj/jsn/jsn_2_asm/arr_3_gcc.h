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
1:
	
	# Perform reads.
	ldr x2, [x0]

	ubfx x1, x2, #0, #8
	mov x3, x0
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #8, #8
	add x3, x0, #1
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #16, #8
	add x3, x0, #2
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #24, #8
	add x3, x0, #3
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #32, #8
	add x3, x0, #4
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #40, #8
	add x3, x0, #5
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #48, #8
	add x3, x0, #6
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x1, x2, #56, #8
	add x3, x0, #7
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
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
