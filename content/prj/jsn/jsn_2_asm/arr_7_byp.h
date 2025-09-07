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
# 
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr
	.type	ns_js_fsk_arr, %function
ns_js_fsk_arr:
	stp x29, x30, [sp, #-0x10]!

	# Init loop variables.
	add x0, x0, #1
	ldr x4, =ns_js_fsk_arr_tbl
	mov x5, #1
	ldr x6, 6f;
	
	# Main loop.
0:

	# Perform reads.
	ldr x2, [x0]
15:
	ldr x3, [x0, #8]
	cmp x2, x6
	b.ne 1f
	add x0, x0, #8
	mov x2, x3
	b 15b
	
1:

	xtr_cmp8 x0, x1, x2, x4, w5, x8, w8, w9, 0x22, 0, 3f, 2f 

	xtr_cmp8 x0, x1, x3, x4, w5, x8, w8, w9, 0x22, 8, 3f, 2f 

	add x0, x0, #16
	b 0b;
	
3:
	add x0, x1, #1
	ldp x29, x30, [sp], #0x10
	ret

	# '"' handling.
2 :
	mov x0, x1
	bl ns_js_fsk_str  
	b 0b;


# Constants.
6:
	.quad 0x2020202020202020
	.size	ns_js_fsk_arr, .-ns_js_fsk_arr

