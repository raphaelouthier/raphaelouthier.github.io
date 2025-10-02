# X0 : data pointer.
# X1 : next data pointer.
# X2 : data0.
# X3 : data1.
# X4 : LUT.
# X5 : depth counter.
# X6 : cst0.
# X7 : scratch.
# X8 : TMP0.
# X9 : TMP1
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr
	.type	ns_js_fsk_arr, %function
ns_js_fsk_arr:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w5, #1
	ldr x4, =ns_js_fsk_arr_tbl
	add x0, x0, #1
	ldr x6, 12f;
	ldr x13, 12f + 24
	
	# Main loop.
0:

	# Perform reads.
	ldp x2, x3, [x0]
	
1:
	cmp x2, x6
	b.ne 2f
	mov x2, x3
	ldr x3, [x0, #16]
	add x0, x0, #8
	b 1b
2:	
	cmp w2, w6
	b.ne 3f
	lsr x2, x2, #32
	add x0, x0, #4
3:	

	# 4 bytes extract compare.
	xtr_cmp4 x0, x1, x2, x4, w5, x8, w8, w9, 0x22, 0, 11f, 10f 
	add x0, x0, #4
	b 0b

	# '"' handling.
10 :
	mov x0, x1
	bl ns_js_fsk_str  
	ldr w2, [x0]
	b 3b;

	# final ']' handling.
11:
	add x0, x1, #1
	ldp x29, x30, [sp], #0x10
	ret


# Constants.
12:
	.quad 0x2020202020202020
	.size	ns_js_fsk_arr, .-ns_js_fsk_arr

