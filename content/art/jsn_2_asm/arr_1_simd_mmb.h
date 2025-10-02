# Relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})

	.align 4
	.global	ns_js_fsk_arr1
	.type	ns_js_fsk_arr1, %function
ns_js_fsk_arr1:
	stp x29, x30, [sp, #-0x10]!
	ldr x1, =6f

	# Skip first '"' char.
	add x0, x0, #1

	# Init depth counter. 
	mov x4, #1
	
	# Constants init.
	ldp d16, d17, [x1]
	ldp d18, d19, [x1, #16]
	ldr d20, [x1, #32]

	# Main loop.
	# Read 8 bytes, check if they are in '[]"'.
	# Then if none is equal, reiterate.
	# If one is equal, move .
1:
	ldr d4, [x0], #8;
	sub v4.8b, v4.8b, v16.8b
	eor v4.8b, v4.8b, v17.8b
	sub v4.8b, v4.8b, v18.8b
	ushl v4.8b, v20.8b, v4.8b
	and v4.8b, v4.8b, v19.8b
	mov x1, v4.D[0]
	cbz x1, 1b

	# Loop exit.
	# Adjust x0 to point to the next character.
	# Adjust x1 to contain the maks of the found character.
	sub x0, x0, #7
	rbit x2, x1
	clz x2, x2
	and x5, x2, #0xf8
	add x0, x0, x2, lsr #3
	lsr x1, x1, x5

	# Process.
	# jump to '['
	tbnz x1, #0, 2f; 
	# jump to ']'
	tbnz x1, #2, 3f; 

	# No jump to '"'
	# '"' handling.
	sub x0, x0, #1
	bl ns_js_fsk_str  
	b 1b;

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

# Constants.
6:
	# d16, quotes.
	.quad 0x2222222222222222
	# d17, 1 << 5.
	.quad 0x2020202020202020
	# d18, 25.
	.quad 0x1919191919191919
	# d19, mask.
	.quad 0x8585858585858585
	# d20, mask.
	.quad 0x0101010101010101
	.size	ns_js_fsk_arr1, .-ns_js_fsk_arr1
