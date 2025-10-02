
# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})

	.align 4
	.global	ns_js_fsk_arr2
	.type	ns_js_fsk_arr2, %function
ns_js_fsk_arr2:
	stp x29, x30, [sp, #-0x10]!
	ldr x1, =6f

	# Skip first '[' char.
	add x0, x0, #1

	# Init depth counter. 
	mov x4, #1
	
	# Constants init.
	ldp d16, d17, [x1]
	ldr d18, [x1, #16]

	# Main loop.
	# Read 8 bytes, check if they are in '[]"'.
	# Then if none is equal, reiterate.
	# If one is equal, move .
1:
	ldr d0, [x0], #8;
	cmeq v1.8b, v0.8b, v16.8b
	cmeq v2.8b, v0.8b, v17.8b
	cmeq v3.8b, v0.8b, v18.8b
	eor3 v1.16b, v1.16b, v2.16b, v3.16b
	mov x2, v1.D[0]
	cbz x2, 1b

	# Loop exit.
	# Adjust x0 to point to the next character.
	# Adjust x1 to contain the maks of the found character.
	mov x1, v0.D[0]
	and x1, x2, x1
	sub x0, x0, #7
	rbit x2, x2
	clz x2, x2
	and x5, x2, #0xf8
	add x0, x0, x2, lsr #3
	lsr x1, x1, x5
	and x1, x1, 0xff

	# Process.
	# jump to '['
	cmp x1, #0x5b
	b.eq 2f; 
	# jump to ']'
	cmp x1, #0x5d
	b.eq 3f; 
	# jump to '"'
	#cmp x1, #0x22
	#b.eq 4f; 
	#b 1b;
	b 4f

	# '[' handling.
2:	
	add x4, x4, #1
	b 1b;

	# ']' handling.
3:	
	sub x4, x4, #1
	cbnz x4, 1b;
	ldp x29, x30, [sp], #0x10
	ret

	# '"' handling.
4:
	sub x0, x0, #1
	bl ns_js_fsk_str  
	b 1b;

# Constants.
6:
	# d16, '"'
	.quad 0x2222222222222222
	# d17, '['
	.quad 0x5b5b5b5b5b5b5b5b
	# d18, ']'.
	.quad 0x5d5d5d5d5d5d5d5d
	.size	ns_js_fsk_arr2, .-ns_js_fsk_arr2
