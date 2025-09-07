
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr0
	.type	ns_js_fsk_arr0, %function
ns_js_fsk_arr0:
	stp x29, x30, [sp, #-0x10]!

	# skip first '"' char.
	add x0, x0, #1

	# init depth counter. 
	ldr x5, 6f
	mov x4, #1

	# main loop.
1:
	ldrb w1, [x0], #1
	sub w2, w1, #32
	lsr x2, x5, x2  
	tbz w2, #0, 1b; 

	# special char detection.
	cmp w1, #0x22 
	b.eq 2f
	cmp w1, #0x5b 
	b.eq 3f
	cmp w1, #0x5d 
	b.eq 4f
	b 1b;

	# no jump to '"'
2:
	# '"' handling.
	sub x0, x0, #1
	bl ns_js_fsk_str  
	b 1b;

	# '[' handling.
3:	
	add x4, x4, #1
	b 1b;

	# ']' handling.
4:	
	sub x4, x4, #1
	cbnz x4, 1b;
	ldp x29, x30, [sp], #0x10
	ret
6:
	.quad 0x2800000000000004 
	.size	ns_js_fsk_arr0, .-ns_js_fsk_arr0
