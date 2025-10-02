	.arch armv8.5-a+sha3
	.file	"arm64.S"
	.text
.Ltext0:
	.file 0 "/home/bt/bt/work/emb" "../kr/std/ns/src/lib/js.c"

##################
# JS string skip #
##################

# JS strink skip.
# Clobbers : 
# - d0 (constant).
# - d1 (read).
# - x0 : return value.
# - x1, x2, x3 : scratch.
	.align 4
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


	.align 4
	.global	ns_js_fsk_str1
	.type	ns_js_fsk_str1, %function
ns_js_fsk_str1:

	# Skip first '"' char.
	add x0, x0, #1
	
	# Constants init.
	ldr d0, 6f;

	# Main loop.
	# Read 8 bytes, compare them to '"' (simd).
	# Then if none is equal, reiterate.
	# Otherwise, move x0 after the first '"' and break.
1:
	ldr d1, [x0];
	add x0, x0, #8
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
	.size	ns_js_fsk_str1, .-ns_js_fsk_str1

	.align 4
	.global	ns_js_fsk_str
	.type	ns_js_fsk_str, %function
ns_js_fsk_str:
	b ns_js_fsk_str1
	.size	ns_js_fsk_str, .-ns_js_fsk_str

#################
# JS array skip #
#################

# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));)
	.align 4
	.global	ns_js_fsk_arr2
	.type	ns_js_fsk_arr2, %function
ns_js_fsk_arr2:
	stp x29, x30, [sp, #-0x10]!

	# Skip first '"' char.
	add x0, x0, #1

	# Init depth counter. 
	ldr x5, 6f
	mov x4, #1

	# Main loop.
1:
	ldrb w1, [x0], #1
	sub w2, w1, #32
	lsr x2, x5, x2  
	tbz w2, #0, 1b; 

	# Special char detection.
	cmp w1, #0x22 
	b.eq 2f
	cmp w1, #0x5b 
	b.eq 3f
	cmp w1, #0x5d 
	b.eq 4f
	b 1b;

	# No jump to '"'
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
	.size	ns_js_fsk_arr2, .-ns_js_fsk_arr2

# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
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

# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})

	.align 4
	.global	ns_js_fsk_arr3
	.type	ns_js_fsk_arr3, %function
ns_js_fsk_arr3:
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
	.size	ns_js_fsk_arr3, .-ns_js_fsk_arr3

# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})

	.align 4
	.global	ns_js_fsk_arr4
	.type	ns_js_fsk_arr4, %function
ns_js_fsk_arr4:
	stp x29, x30, [sp, #-0x10]!

	# Skip first '[' char.
	add x0, x0, #1

	# Init depth counter. 
	mov w4, #1
	ldr x6, =ns_js_fsk_arr_tbl
	
	# Main loop.
1:
	
	# Perform reads.
	ldr x2, [x0], #8

	ubfx x1, x2, #0, #8
	sub x3, x0, #8
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #8, #8
	sub x3, x0, #7
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #16, #8
	sub x3, x0, #6
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #24, #8
	sub x3, x0, #5
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #32, #8
	sub x3, x0, #4
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #40, #8
	sub x3, x0, #3
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #48, #8
	sub x3, x0, #2
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #56, #8
	sub x3, x0, #1
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	b 1b;

	# '"' handling.
2 :
	sub x0, x3, #1
	bl ns_js_fsk_str  
	b 1b;


3:
	add x0, x3, #1
	ldp x29, x30, [sp], #0x10
	ret

	# Start the computation of the offset
	# of the next interesting char in x2.
	cmeq v1.8b, v0.8b, v16.8b
	cmeq v2.8b, v0.8b, v17.8b
	cmeq v3.8b, v0.8b, v18.8b
	eor3 v1.16b, v1.16b, v2.16b, v3.16b
	mov x3, v1.D[0]
	rbit x3, x3
	clz x3, x3
	add x0, x0, x3, lsr #3;


# Constants.
6:
	# d16, '"'
	.quad 0x2222222222222222
	# d17, '['
	.quad 0x5b5b5b5b5b5b5b5b
	# d18, ']'.
	.quad 0x5d5d5d5d5d5d5d5d
	.size	ns_js_fsk_arr4, .-ns_js_fsk_arr4


	.align 4
	.global	ns_js_fsk_arr5
	.type	ns_js_fsk_arr5, %function
ns_js_fsk_arr5:
	stp x29, x30, [sp, #-0x10]!
	ldr x1, =6f

	# Skip first '[' char.
	add x0, x0, #1

	# Init depth counter. 
	mov x4, #1
	ldr x6, =ns_js_fsk_arr_tbl
	
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

	ldrb w2, [x6, x1]
	sxtb x2, w2
	add x4, x4, x2
	cbz x4, 3f;

	cmp x1, #0x22
	b.eq 2f; 
	b 1b;

	# '"' handling.
2 :
	sub x0, x0, #1
	bl ns_js_fsk_str  
	b 1b;

3:
	ldp x29, x30, [sp], #0x10
	ret

# Constants.
6:
	# d16, '"'
	.quad 0x2222222222222222
	# d17, '['
	.quad 0x5b5b5b5b5b5b5b5b
	# d18, ']'.
	.quad 0x5d5d5d5d5d5d5d5d
	.size	ns_js_fsk_arr5, .-ns_js_fsk_arr5

	.global	ns_js_fsk_arr7
	.type	ns_js_fsk_arr7, %function
ns_js_fsk_arr7:
    stp    x29, x30, [sp, #-0x20]!
    mov    x1, x0
    add    x0, x0, #0x1
    mov    x29, sp
    stp    x19, x20, [sp, #0x10]
    ldr    x20, =ns_js_fsk_arr_tbl
    ldur   x2, [x1, #0x1]
    ldur   x3, [x1, #0x9]
    and    w1, w2, #0xff
    ldrsb  w19, [x20, w1, sxtw]
    adds   w19, w19, #0x1
    b.eq   10f;
14:
    cmp    w1, #0x22
    b.eq   11f;
    ubfx   w5, w2, #8, #8
    add    x1, x0, #0x1
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    ubfx   w5, w2, #16, #8
    add    x1, x0, #0x2
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    lsr    w5, w2, #24
    add    x1, x0, #0x3
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    ubfx   x5, x2, #32, #8
    add    x1, x0, #0x4
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    ubfx   x5, x2, #40, #8
    add    x1, x0, #0x5
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    ubfx   x5, x2, #48, #8
    add    x1, x0, #0x6
    ldrsb  w4, [x20, w5, sxtw]
    adds   w19, w19, w4
    b.eq   12f
    cmp    w5, #0x22
    b.eq   13f
    lsr    x4, x2, #56
    add    x1, x0, #0x7
    mov    x2, x4
    ldrsb  w4, [x20, x4]
    adds   w19, w19, w4
    b.eq   12f
    cmp    x2, #0x22
    b.eq   13f
    and    w4, w3, #0xff
    add    x1, x0, #0x8
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    ubfx   w4, w3, #8, #8
    add    x1, x0, #0x9
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    ubfx   w4, w3, #16, #8
    add    x1, x0, #0xa
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    lsr    w4, w3, #24
    add    x1, x0, #0xb
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    ubfx   x4, x3, #32, #8
    add    x1, x0, #0xc
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    ubfx   x4, x3, #40, #8
    add    x1, x0, #0xd
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    ubfx   x4, x3, #48, #8
    add    x1, x0, #0xe
    ldrsb  w2, [x20, w4, sxtw]
    adds   w19, w19, w2
    b.eq   12f
    cmp    w4, #0x22
    b.eq   13f
    lsr    x2, x3, #56
    add    x1, x0, #0xf
    mov    x3, x2
    ldrsb  w2, [x20, x2]
    adds   w19, w19, w2
    b.eq   12f
    cmp    x3, #0x22
    b.eq   13f
    add    x0, x0, #0x10
15:
    ldp    x2, x3, [x0]
    and    w1, w2, #0xff
    ldrsb  w4, [x20, w1, sxtw]
    adds   w19, w19, w4
    b.ne   14b
10:
    mov    x1, x0
12:
    ldp    x19, x20, [sp, #0x10]
    add    x0, x1, #0x1
    ldp    x29, x30, [sp], #0x20
    ret
13:
    mov    x0, x1
11:
    bl     ns_js_fsk_str
    b      15b
	.size	ns_js_fsk_arr7, .-ns_js_fsk_arr7


# JS Array skip.
# Clobbers 
# - d16, d17, d18, d19, d20 (constants).
# - d4 (read) 
# - x0, x1, x2, x3, x4, x5. Scratch.
# The JS array skip relies on the following trick to
# make a quick byte membership test for '[]"' :
# ({u8 shf = (((c - '"') ^ ((u8) 1 << 5)) - (u8) 25); !((shf <= 7) && ((0xa1 >> shf) & 1));})

	.align 4
	.global	ns_js_fsk_arr8
	.type	ns_js_fsk_arr8, %function
ns_js_fsk_arr8:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w4, #1
	ldr x6, =ns_js_fsk_arr_tbl
	mov x3, x0
	add x0, x0, #1
	
	# Main loop.
	
	# Perform reads.
	ldr x2, [x3, #1]
	mov x3, x0

	ubfx x1, x2, #0, #8
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
1:
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #8, #8
	add x3, x0, #1
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #16, #8
	add x3, x0, #2
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #24, #8
	add x3, x0, #3
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #32, #8
	add x3, x0, #4
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #40, #8
	add x3, x0, #5
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	ubfx x1, x2, #48, #8
	add x3, x0, #6
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x1, #0x22
	b.eq 2f; 

	ubfx x5, x2, #56, #8
	add x3, x0, #7
	ldrsb w12, [x6, w5, sxtw]
	adds w4, w4, w12
	b.eq 3f;
	cmp x5, #0x22
	b.eq 2f; 

	# Perform read.
	add x0, x0, #8
5:
	ldr x2, [x0]
	mov x3, x0

	ubfx x1, x2, #0, #8
	ldrsb w12, [x6, w1, sxtw]
	adds w4, w4, w12
	b.ne 1b;

3:
	add x0, x3, #1
	ldp x29, x30, [sp], #0x10
	ret


	# '"' handling.
2 :
	mov x0, x3
	bl ns_js_fsk_str  
	b 5b;

	.size	ns_js_fsk_arr8, .-ns_js_fsk_arr8

# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr9
	.type	ns_js_fsk_arr9, %function
ns_js_fsk_arr9:
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

	ubfx x1, x2, #0, #8
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
	.size	ns_js_fsk_arr9, .-ns_js_fsk_arr9


# Best result so far : 29.100
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr10
	.type	ns_js_fsk_arr10, %function
ns_js_fsk_arr10:
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
	add x3, x0, #4
	ldrsb w8, [x6, w12, sxtw]
	adds w4, w4, w8
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	ubfx x13, x2, #40, #8
	add x3, x0, #5
	ldrsb w9, [x6, w13, sxtw]
	adds w4, w4, w9
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	ubfx x14, x2, #48, #8
	add x3, x0, #6
	ldrsb w10, [x6, w14, sxtw]
	adds w4, w4, w10
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	ubfx x15, x2, #56, #8
	add x3, x0, #7
	ldrsb w11, [x6, w15, sxtw]
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
	.size	ns_js_fsk_arr10, .-ns_js_fsk_arr10


# Base interleaved one. Has good results.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr11
	.type	ns_js_fsk_arr11, %function
ns_js_fsk_arr11:
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
	ldrsb w5, [x6, w12, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	ubfx x13, x2, #8, #8
	add x3, x0, #1
	ldrsb w5, [x6, w13, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	ubfx x14, x2, #16, #8
	add x3, x0, #2
	ldrsb w5, [x6, w14, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	ubfx x15, x2, #24, #8
	add x3, x0, #3
	ldrsb w5, [x6, w15, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x15, #0x22
	b.eq 2f; 

	ubfx x12, x2, #32, #8
	add x3, x0, #4
	ldrsb w5, [x6, w12, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	ubfx x13, x2, #40, #8
	add x3, x0, #5
	ldrsb w5, [x6, w13, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	ubfx x14, x2, #48, #8
	add x3, x0, #6
	ldrsb w5, [x6, w14, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	ubfx x15, x2, #56, #8
	add x3, x0, #7
	ldrsb w5, [x6, w15, sxtw]
	adds w4, w4, w5
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
	.size	ns_js_fsk_arr11, .-ns_js_fsk_arr11

# Base with Non-interleaved ubfx + lookup.
# Same output as the other -> four 4 are always successfully speculatively executed.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr12
	.type	ns_js_fsk_arr12, %function
ns_js_fsk_arr12:
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
	add x3, x0, #4
	ldrsb w5, [x6, w12, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	ubfx x13, x2, #40, #8
	add x3, x0, #5
	ldrsb w5, [x6, w13, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	ubfx x14, x2, #48, #8
	add x3, x0, #6
	ldrsb w5, [x6, w14, sxtw]
	adds w4, w4, w5
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	ubfx x15, x2, #56, #8
	add x3, x0, #7
	ldrsb w5, [x6, w15, sxtw]
	adds w4, w4, w5
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
	.size	ns_js_fsk_arr12, .-ns_js_fsk_arr12



# 29.400
# Less strict non-speculative one where we ubfx and let load be conditioned by branch pred.
# Better than the next but worse since we don't usually go this far.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr13
	.type	ns_js_fsk_arr13, %function
ns_js_fsk_arr13:
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


	add x3, x0, #4
	ldrsb w8, [x6, w12, sxtw]
	adds w4, w4, w8
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	add x3, x0, #5
	ldrsb w9, [x6, w13, sxtw]
	adds w4, w4, w9
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	add x3, x0, #6
	ldrsb w10, [x6, w14, sxtw]
	adds w4, w4, w10
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	add x3, x0, #7
	ldrsb w11, [x6, w15, sxtw]
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
	.size	ns_js_fsk_arr13, .-ns_js_fsk_arr13



# Strict non-speculative one : 29.600 in average, bad because we fight against branch pred here.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr14
	.type	ns_js_fsk_arr14, %function
ns_js_fsk_arr14:
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
	.size	ns_js_fsk_arr14, .-ns_js_fsk_arr14


# Back to 29.600, which makes sense as it's just like the totally non-interleaved one.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr_15
	.type	ns_js_fsk_arr_15, %function
ns_js_fsk_arr_15:
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

	add x0, x0, #4
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
	.size	ns_js_fsk_arr_15, .-ns_js_fsk_arr_15

# -> 31, which suggests that reading 4 bytes at a time is better for perf. 
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr_16
	.type	ns_js_fsk_arr_16, %function
ns_js_fsk_arr_16:
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

	ldrsb w8, [x6, w12, sxtw]
	ldrsb w9, [x6, w13, sxtw]

	adds w4, w4, w8
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	add x3, x0, #1
	adds w4, w4, w9
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	add x0, x0, #2
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
	.size	ns_js_fsk_arr_16, .-ns_js_fsk_arr_16


# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr17
	.type	ns_js_fsk_arr17, %function
ns_js_fsk_arr17:
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
	.size	ns_js_fsk_arr17, .-ns_js_fsk_arr17

.macro xtr_cmp1 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, bit_stt, val_qot, val_add, lbl_out, lbl_qot
	ubfx \xrg_tm0, \xrg_dat, #0 + \bit_stt, #8
	add \xrg_dst, \xrg_src, #\val_add
	ldrsb \wrg_tm1, [\xrg_tbl, \wrg_tm0, sxtw]
	adds \wrg_ctr, \wrg_ctr, \wrg_tm1
	b.eq \lbl_out;
	cmp \xrg_tm0, #\val_qot
	b.eq \lbl_qot; 
.endm

.macro xtr_cmp2 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
.endm

.macro xtr_cmp4 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 16, \val_qot, \val_bas + 2, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 24, \val_qot, \val_bas + 3, \lbl_out, \lbl_qot
.endm

.macro xtr_cmp8 xrg_src, xrg_dst, xrg_dat, xrg_tbl, wrg_ctr, xrg_tm0, wrg_tm0, wrg_tm1, val_qot, val_bas, lbl_out, lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 0, \val_qot, \val_bas + 0, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 8, \val_qot, \val_bas + 1, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 16, \val_qot, \val_bas + 2, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 24, \val_qot, \val_bas + 3, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 32, \val_qot, \val_bas + 4, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 40, \val_qot, \val_bas + 5, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 48, \val_qot, \val_bas + 6, \lbl_out, \lbl_qot
	xtr_cmp1 \xrg_src, \xrg_dst, \xrg_dat, \xrg_tbl, \wrg_ctr, \xrg_tm0, \wrg_tm0, \wrg_tm1, 56, \val_qot, \val_bas + 7, \lbl_out, \lbl_qot
.endm



# TODO

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
	.global	ns_js_fsk_arr18
	.type	ns_js_fsk_arr18, %function
ns_js_fsk_arr18:
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
	.size	ns_js_fsk_arr18, .-ns_js_fsk_arr18


# Base with Non-interleaved ubfx + lookup.
# Same output as the other -> four 4 are always successfully speculatively executed.
# JS Array skip.
	.align 4
	.global	ns_js_fsk_arr19
	.type	ns_js_fsk_arr19, %function
ns_js_fsk_arr19:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w4, #1
	ldr x6, =ns_js_fsk_arr_tbl
	ldr x16, =ns_js_fsk_arr_tbl1
	add x0, x0, #1
	ldr x7, 6f;
	
	# Main loop.
1:

	# Perform reads.
	ldp x2, x3, [x0]
14:
	lsr x1, x2, #32
	cmp x2, x7
	b.ne 12f
	mov x2, x3
	ldr x3, [x0, #16]
	add x0, x0, #8
	b 14b
12:	

	cmp w2, w7
	b.ne 12f
	mov x2, x1
	add x0, x0, #4
12:	


	mov x3, x0

	ubfx x12, x2, #0, #8
	ldrsb w8, [x6, w12, sxtw]
	adds w4, w4, w8, sxtb
	b.eq 3f;
	cmp x12, #0x22
	b.eq 2f; 

	ubfx x13, x2, #8, #8
	ldrsb w9, [x6, w13, sxtw]
	add x3, x0, #1
	adds w4, w4, w9, sxtb
	b.eq 3f;
	cmp x13, #0x22
	b.eq 2f; 

	ubfx x14, x2, #16, #8
	ldrsb w10, [x6, w14, sxtw]
	add x3, x0, #2
	adds w4, w4, w10, sxtb
	b.eq 3f;
	cmp x14, #0x22
	b.eq 2f; 

	ubfx x15, x2, #24, #8
	ldrsb w11, [x6, w15, sxtw]
	add x3, x0, #3
	adds w4, w4, w11, sxtb
	b.eq 3f;
	cmp x15, #0x22
	b.eq 2f; 

	add x0, x0, #4
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
6:
	.quad 0x2020202020202020
	.size	ns_js_fsk_arr19, .-ns_js_fsk_arr19


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
	.global	ns_js_fsk_arr20
	.type	ns_js_fsk_arr20, %function
ns_js_fsk_arr20:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w5, #1
	ldr x4, =ns_js_fsk_arr_tbl
	add x0, x0, #1
	ldr x6, 6f;
	
	# Main loop.
0:
	ldr w2, [x0]
	cmp w2, w6
	b.eq 10f;

	xtr_cmp4 x0, x1, x2, x4, w5, x8, w8, w9, 0x22, 0, 3f, 2f 
	add x0, x0, #4
	b.eq 3f;
	b 0b;


	# '"' handling.
2 :
	mov x0, x1
	bl ns_js_fsk_str  
	b 0b;

	# final ']' handling.
3:
	add x0, x1, #1
	ldp x29, x30, [sp], #0x10
	ret

	# Mass space skip.
10:
	add x0, x0, #4

	# Perform reads.
	ldp x2, x3, [x0]
11:
	cmp x2, x6
	b.ne 12f
	mov x2, x3
	ldr x3, [x0, #16]
	add x0, x0, #8
	b 11b
12:	

	# TODO move upper if advantage.
	eor x3, x2, x6
	rev x3, x3
	clz x3, x3
	add x0, x0, x3, lsr 3
	b 0b;

# Constants.
6:
	.quad 0x2020202020202020
	.size	ns_js_fsk_arr20, .-ns_js_fsk_arr20


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
	.global	ns_js_fsk_arr21
	.type	ns_js_fsk_arr21, %function
ns_js_fsk_arr21:
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
	.size	ns_js_fsk_arr21, .-ns_js_fsk_arr21


# 22 -> 31, -50% perf.
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
	.global	ns_js_fsk_arr22
	.type	ns_js_fsk_arr22, %function
ns_js_fsk_arr22:
	stp x29, x30, [sp, #-0x10]!

	# Init depth counter. 
	mov w5, #1
	ldr x4, =ns_js_fsk_arr_tbl
	add x0, x0, #1
	ldr x6, 12f;
	
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
	bl ns_js_fsk_arr_str  
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
	.size	ns_js_fsk_arr22, .-ns_js_fsk_arr22



	.align 4
	.global	ns_js_fsk_arr_str
	.type	ns_js_fsk_arr_str, %function
ns_js_fsk_arr_str:

	# Skip first '"' char.
	add x0, x0, #1
	
	# Constants init.
	ldr d0, 6f;
	ldr d3, 6f + 8;
	ldr d4, 6f + 16;

	# Main loop.
	# Read 8 bytes, compare them to '"' (simd).
	# Then if none is equal, reiterate.
	# Otherwise, move x0 after the first '"' and break.
1:
	ldr d1, [x0];
	add x0, x0, #8
	cmeq v1.8b, v1.8b, v0.8b
	mov x1, v1.D[0]
	cbz x1, 1b
	
	# Loop exit. Adjust x0 to point to the char after '"'.
	sub x0, x0, #7
	rbit x1, x1
	clz x1, x1
	add x0, x0, x1, lsr 3

	# Now cycle while we don't see any special char. 
2:
brkplz:
	ld1r {v1.2s}, [x0];
	add x3, x0, #4
	cmeq v5.8b, v1.8b, v3.8b
	cmeq v6.8b, v1.8b, v4.8b
	mov x1, v5.D[0]
	mov x2, v6.D[0]
	# If [] hit, then leave now.
	cbnz x1, 4f
	# If no '"' hit, then reiterate.
	cbnz x2, 3f
	mov x0, x3
	b 2b

	# " hit section.
3:
	sub x3, x3, #3
	rbit x2, x2
	clz x2, x2
	add x0, x3, x2, lsr 3
	b 1b;

4:
	ret

# Constants.
6:
	.quad 0x2222222222222222
	.quad 0x5b5b5b5b5d5d5d5d
	.quad 0x0000000022222222
	.size	ns_js_fsk_arr_str, .-ns_js_fsk_arr_str



	.align 4
	.global	ns_js_fsk_arr
	.type	ns_js_fsk_arr, %function
ns_js_fsk_arr:
	b ns_js_fsk_arr22
	.size	ns_js_fsk_arr, .-ns_js_fsk_arr

