# JS strink skip.
	.global	ns_js_fsk_str0
	.type	ns_js_fsk_str0, %function
ns_js_fsk_str0:

	# Skip first '"' char.
	add x0, x0, #1
	
	# Constants init.
	ldr d0, 6f;

	# Main loop.
	# Read 8 bytes, compare them to '"' (simd).
	# Then if none is equal, reiterate.
	# Otherwise, move x0 after the first '"' and break.
1:
	ldr d1, [x0], #8;
	cmeq v1.8b, v1.8b, v0.8b
	mov x1, v1.D[0]
	cbz x1, 1b
	
	# Loop exit. Adjust x0 to point to the char after '"'.
	sub x0, x0, #7
	rbit x1, x1
	clz x1, x1
	add x0, x0, x1, lsr 3

	# If previous char is '\', corner case, as we need to
	# Determine if it is meaningful.
	ldrb w1, [x0, #-2]
	cmp x1, 0x5c
	b.ne 3f
	
	# Count the number of '/' before '"'.
	# If it is even, return.
	# If it is odd, re-enter the loop
	mov x1, 0
	sub x2, x0, #3
2:
	add x1, x1, #1
	ldrb w3, [x2], #-1
	cmp x3, 0x5c
	b.eq 2b;
	tbnz x1, #0, 1b
3:
	ret

# Constants.
6:
	.quad 0x2222222222222222
	.size	ns_js_fsk_str0, .-ns_js_fsk_str0
