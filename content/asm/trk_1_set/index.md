--- 
title: "Assembly trick : bijective transformations of the char set." 
summary: "Applying the membership test to faraway characters."
categories: ["C","Assembly",] 
#externalUrl: "" 
showSummary: true
date: 2025-08-13 
showTableOfContents : true
---


## Introduction

While I was working on [the third part of my json parsing optimization project](/prj/jsn/jsn_2_asm) involving ARM SIMD operations, I reached the limits of what the [trick that I mentioned in my previous post](/asm/trk_0_set) allows.

My use case was focused around json array and object skipping. I needed to verify as quickly as possible that a character was a member or not of a small set (either (`[`, `]`, `"`) for arrays or (`{`, `}`, `"`) for objects) and if not, just proceed to the next character.

This problem is quite simple and the compiler is able to properly optimize an expression like

```C
if ((c != '"') && (c != '{') && (c != '}')) continue;
```

Though, in my case, what I really wanted to do was :
- read N bytes at a time.
- check if any of those N bytes is in the target set.
- if none is, just skip those N characters at once.

Using ARM's SIMD instructions with vector elements of one byte sounded like the right approach for this. But there is a catch.

Remember the set membership test from the last article ? This trick was essentially using a register as a 64 entries lookup table for a consecutive range of chars, each bit being set if the char was a member of the target set and clear if not.

Our problem here is that if I am using SIMD operations, I can only do calculations that involve bytes. Hence, if I want to apply the same trick, my bitmask can only be 8 bits wide, which limits me to testing constant ranges of 8 characters.

Problem : the chars that compose my sets (either (`[`, `]`, `"`) for arrays or (`{`, `}`, `"`) for objects) are not 8-wide :

| char | ASCII value |
|-----------|-------------|
| `"`      | 32           |
| `[`      | 91           |
| `]`      | 93          |
| `{`      | 123          |
| `}`     | 125          |


This is bad, as again, to apply our bitmask-based trick, we need to restrict the checked ascii values to the [0, 7] range.

But we are nevertheless lucky : the characters that compose our target sets are constant, which will allow us to apply another clever trick.

Rather than using the char's value itself, we will find a bijective function whose images of our target chars will all be in [0, 7].

This bijective function will be composed of multiple sequential SIMD instructions applied to our read characters.

## Charset visualization

Throughout this article I'll heavily rely on reversible operations that affect a character's value.

To visualize the ascii charset in a variety of ways, `man ascii` is your best friend.

I'll show the effects of some functions on the ascii character set with the following kind of diagram. For every cell in the array indexed by `(x, y)`, it shows the ascii value of `(x << 4) & y` transformed by some given operation.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |       0 @ P ` p                 |
1 |     ! 1 A Q a q                 |
2 |     " 2 B R b r                 |
3 |     # 3 C S c s                 |
4 |     $ 4 D T d t                 |
5 |     % 5 E U e u                 |
6 |     & 6 F V f v                 |
7 |     ' 7 G W g w                 |
8 |     ( 8 H X h x                 |
9 |     ) 9 I Y i y                 |
A |     * : J Z j z                 |
B |     + ; K [ k {                 |
C |     , < L \ l |                 |
D |     - = M ] m }                 |
E |     . > N ^ n ~                 |
F |     / ? O _ o                   |
   ---------------------------------
```

Here no function is applied, and hence, we have our native ascii charset layout.

## What we want, graphically

Let's use the same kind of diagram to illustrate what we want to do.

Remember that our objective is to find a function whose image of our three characters ("[]) or ("{}) is in the [0, 7] range.

This range is graphically displayed here :

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | X                               |
1 | X                               |
2 | X                               |
3 | X                               |
4 | X                               |
5 | X                               |
6 | X                               |
7 | X                               |
8 |                                 |
9 |                                 |
A |                                 |
B |                                 |
C |                                 |
D |                                 |
E |                                 |
F |                                 |
   ---------------------------------
```

Now, if we find a bijective function that puts our three target characters in the range highlighted above, we won, as we will have found a bijective function that projects three values in [0, 7] in our target set.

The inverse of this function will hence be a bijective function that projects our three target characters in the [0, 7] set.

So watch for those diagrams !

## Operation 0 : ADD

An operation that is certainly supported in SIMD is the addition / subtraction.

Let's add one to our initial value characters and see what that does.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |     ! 1 A Q a q                 |
1 |     " 2 B R b r                 |
2 |     # 3 C S c s                 |
3 |     $ 4 D T d t                 |
4 |     % 5 E U e u                 |
5 |     & 6 F V f v                 |
6 |     ' 7 G W g w                 |
7 |     ( 8 H X h x                 |
8 |     ) 9 I Y i y                 |
9 |     * : J Z j z                 |
A |     + ; K [ k {                 |
B |     , < L \ l |                 |
C |     - = M ] m }                 |
D |     . > N ^ n ~                 |
E |     / ? O _ o                   |
F |     0 @ P ` p                   |
   ---------------------------------
```

See anything ? Yeah all characters were translated of one position (wrt overflow).

Let's now apply an offset of 33, which is the ascii code for `!`.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | ! 1 A Q a q                     |
1 | " 2 B R b r                     |
2 | # 3 C S c s                     |
3 | $ 4 D T d t                     |
4 | % 5 E U e u                     |
5 | & 6 F V f v                     |
6 | ' 7 G W g w                     |
7 | ( 8 H X h x                     |
8 | ) 9 I Y i y                     |
9 | * : J Z j z                     |
A | + ; K [ k {                     |
B | , < L \ l |                     |
C | - = M ] m }                     |
D | . > N ^ n ~                     |
E | / ? O _ o                       |
F | 0 @ P ` p                       |
   ---------------------------------
```

That made `!` move to the position 0 of our target range. Useful ! Now we just have to find a function that puts our three characters in any range of width 8 (any `[N, N + 7]` range, N being constant), and we'll be able to translate this range in [0, 7].

## Operation 1 : XOR

Another operation that is surely supported in SIMD (since it behaves exactly the same as the non-SIMD one...) is the bitwise XOR.

Simply put, XOR is a bitwise operation for which each bit of `val ^ mask` is :
- `val`'s corresponding bit if `mask`'s corresponding bit is 0.
- not(`val`'s corresponding bit) if `mask`'s corresponding bit is 0.

We can hence use xor to invert specific bits in our character value.

Let's check the effects of XOR-ing bits 4, 5, 6, and 7 of our ascii table.

```
Bit 4 : Swaps neighbour columns.
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |     0   P @ p `                 |
1 |     1 ! Q A q a                 |
2 |     2 " R B r b                 |
3 |     3 # S C s c                 |
4 |     4 $ T D t d                 |
5 |     5 % U E u e                 |
6 |     6 & V F v f                 |
7 |     7 ' W G w g                 |
8 |     8 ( X H x h                 |
9 |     9 ) Y I y i                 |
A |     : * Z J z j                 |
B |     ; + [ K { k                 |
C |     < , \ L | l                 |
D |     = - ] M } m                 |
E |     > . ^ N ~ n                 |
F |     ? / _ O   o                 |
   ---------------------------------

Bit 5 : Swaps neighbour groups of 2 columns.
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |   0     ` p @ P                 |
1 | ! 1     a q A Q                 |
2 | " 2     b r B R                 |
3 | # 3     c s C S                 |
4 | $ 4     d t D T                 |
5 | % 5     e u E U                 |
6 | & 6     f v F V                 |
7 | ' 7     g w G W                 |
8 | ( 8     h x H X                 |
9 | ) 9     i y I Y                 |
A | * :     j z J Z                 |
B | + ;     k { K [                 |
C | , <     l | L \                 |
D | - =     m } M ]                 |
E | . >     n ~ N ^                 |
F | / ?     o   O _                 |
   ---------------------------------

Bit 6 : Swaps neighbour groups of 4 columns.
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | @ P ` p       0                 |
1 | A Q a q     ! 1                 |
2 | B R b r     " 2                 |
3 | C S c s     # 3                 |
4 | D T d t     $ 4                 |
5 | E U e u     % 5                 |
6 | F V f v     & 6                 |
7 | G W g w     ' 7                 |
8 | H X h x     ( 8                 |
9 | I Y i y     ) 9                 |
A | J Z j z     * :                 |
B | K [ k {     + ;                 |
C | L \ l |     , <                 |
D | M ] m }     - =                 |
E | N ^ n ~     . >                 |
F | O _ o       / ?                 |
   ---------------------------------

Bit 7 : Swaps neighbour groups of 8 columns.
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |                       0 @ P ` p |
1 |                     ! 1 A Q a q |
2 |                     " 2 B R b r |
3 |                     # 3 C S c s |
4 |                     $ 4 D T d t |
5 |                     % 5 E U e u |
6 |                     & 6 F V f v |
7 |                     ' 7 G W g w |
8 |                     ( 8 H X h x |
9 |                     ) 9 I Y i y |
A |                     * : J Z j z |
B |                     + ; K [ k { |
C |                     , < L \ l | |
D |                     - = M ] m } |
E |                     . > N ^ n ~ |
F |                     / ? O _ o   |
   ---------------------------------
```

This operation has an interesting side effect : it brings distant columns closer : note how flipping bit 4 made (among others) columns 0 and 3 move to (resp) columns 1 and 2, effectively making them touch.

This has the potential to move distant characters in a close range, and will be the base of the transformation for set `("[])`.

# Detecting ", [ and ] using one XOR and two ADDs.

Let's first start with our ASCII charset.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |     ! 1 A Q a q                 |
1 |     " 2 B R b r                 |
2 |     # 3 C S c s                 |
3 |     $ 4 D T d t                 |
4 |     % 5 E U e u                 |
5 |     & 6 F V f v                 |
6 |     ' 7 G W g w                 |
7 |     ( 8 H X h x                 |
8 |     ) 9 I Y i y                 |
9 |     * : J Z j z                 |
A |     + ; K [ k {                 |
B |     , < L \ l |                 |
C |     - = M ] m }                 |
D |     . > N ^ n ~                 |
E |     / ? O _ o                   |
F |     0 @ P ` p                   |
   ---------------------------------
```

First thing to note is that `[` and `]` are on the same column and almost consecutive. This is good as we just need to move `"` closer.

Then let's note that `"` is on a column separated by two other columns.

This smells like a XOR opportunity. But first we need to move them to a swappable range.

Let's add 34 (ascii code for `"`).

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | " 2 B R b r                     |
1 | # 3 C S c s                     |
2 | $ 4 D T d t                     |
3 | % 5 E U e u                     |
4 | & 6 F V f v                     |
5 | ' 7 G W g w                     |
6 | ( 8 H X h x                     |
7 | ) 9 I Y i y                     |
8 | * : J Z j z                     |
9 | + ; K [ k {                     |
A | , < L \ l |                     |
B | - = M ] m }                     |
C | . > N ^ n ~                     |
D | / ? O _ o                       |
E | 0 @ P ` p                       |
F | 1 A Q a q                     ! |
   ---------------------------------
```

Now we just need to flip bit 5 to reorder our two columns the way we want :

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | B R " 2     b r                 |
1 | C S # 3     c s                 |
2 | D T $ 4     d t                 |
3 | E U % 5     e u                 |
4 | F V & 6     f v                 |
5 | G W ' 7     g w                 |
6 | H X ( 8     h x                 |
7 | I Y ) 9     i y                 |
8 | J Z * :     j z                 |
9 | K [ + ;     k {                 |
A | L \ , <     l |                 |
B | M ] - =     m }                 |
C | N ^ . >     n ~                 |
D | O _ / ?     o                   |
E | P ` 0 @     p                   |
F | Q a 1 A     q             !     |
   ---------------------------------
```

See it now ? We're almost there, as now our three characters are in an 8 wide range.

We just need to move `[` at position 0 by applying another offset of 25 and we'll be done.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | [ + ;     k {                 K |
1 | \ , <     l |                 L |
2 | ] - =     m }                 M |
3 | ^ . >     n ~                 N |
4 | _ / ?     o                   O |
5 | ` 0 @     p                   P |
6 | a 1 A     q             !     Q |
7 | " 2     b r                 B R |
8 | # 3     c s                 C S |
9 | $ 4     d t                 D T |
A | % 5     e u                 E U |
B | & 6     f v                 F V |
C | ' 7     g w                 G W |
D | ( 8     h x                 H X |
E | ) 9     i y                 I Y |
F | * :     j z                 J Z |
   ---------------------------------
```

And we have our transformation that puts [0, 7] in our target charset.

Let's inverse it to get the transformation that puts our target charset in [0, 7]. Our SIMD sequence will need :
- `ADD -25`
- `XOR (1 << 5)`
- `ADD -34`

Which is just 3 SIMD instructions.

# Detecting ", { and } using one dual XOR and two ADDs.

Let's do the same to quickly detect `("{})`, but this time, using a more elaborated XOR.

We'll be lucky again as `{` and `}` are again on the same column and closeby. But they are in a different column which will cause us a bit of trouble.

Let's start again with our ascii charset.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |       0 @ P ` p                 |
1 |     ! 1 A Q a q                 |
2 |     " 2 B R b r                 |
3 |     # 3 C S c s                 |
4 |     $ 4 D T d t                 |
5 |     % 5 E U e u                 |
6 |     & 6 F V f v                 |
7 |     ' 7 G W g w                 |
8 |     ( 8 H X h x                 |
9 |     ) 9 I Y i y                 |
A |     * : J Z j z                 |
B |     + ; K [ k {                 |
C |     , < L \ l |                 |
D |     - = M ] m }                 |
E |     . > N ^ n ~                 |
F |     / ? O _ o                   |
   ---------------------------------
```

Our chars are in two columns, but this time they have 4 columns in between.

We'll have to first bring them to a position suited for XOR. Let's rotate columns on the left by adding 16.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |     0 @ P ` p                   |
1 |   ! 1 A Q a q                   |
2 |   " 2 B R b r                   |
3 |   # 3 C S c s                   |
4 |   $ 4 D T d t                   |
5 |   % 5 E U e u                   |
6 |   & 6 F V f v                   |
7 |   ' 7 G W g w                   |
8 |   ( 8 H X h x                   |
9 |   ) 9 I Y i y                   |
A |   * : J Z j z                   |
B |   + ; K [ k {                   |
C |   , < L \ l |                   |
D |   - = M ] m }                   |
E |   . > N ^ n ~                   |
F |   / ? O _ o                     |
   ---------------------------------
```

Okay, now let's XOR bit 6, which will in practice swap adjacent blocks of 4 columns.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | P ` p       0 @                 |
1 | Q a q     ! 1 A                 |
2 | R b r     " 2 B                 |
3 | S c s     # 3 C                 |
4 | T d t     $ 4 D                 |
5 | U e u     % 5 E                 |
6 | V f v     & 6 F                 |
7 | W g w     ' 7 G                 |
8 | X h x     ( 8 H                 |
9 | Y i y     ) 9 I                 |
A | Z j z     * : J                 |
B | [ k {     + ; K                 |
C | \ l |     , < L                 |
D | ] m }     - = M                 |
E | ^ n ~     . > N                 |
F | _ o       / ? O                 |
   ---------------------------------
```

We now see that our target chars are now separated by only 2 columns that, if they were just removed, would make our range be exactly 8 wide.

Let's bring those two columns closer by flipping bit 4 :

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | ` P   p     @ 0                 |
1 | a Q   q !   A 1                 |
2 | b R   r "   B 2                 |
3 | c S   s #   C 3                 |
4 | d T   t $   D 4                 |
5 | e U   u %   E 5                 |
6 | f V   v &   F 6                 |
7 | g W   w '   G 7                 |
8 | h X   x (   H 8                 |
9 | i Y   y )   I 9                 |
A | j Z   z *   J :                 |
B | k [   { +   K ;                 |
C | l \   | ,   L <                 |
D | m ]   } -   M =                 |
E | n ^   ~ .   N >                 |
F | o _     /   O ?                 |
   ---------------------------------
```

which gives us our 8-wide range, that we now just have to translate in [0, 7] by adding an offset of 59.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | { +   K ;                 k [   |
1 | | ,   L <                 l \   |
2 | } -   M =                 m ]   |
3 | ~ .   N >                 n ^   |
4 |   /   O ?                 o _   |
5 |     @ 0                 ` P   p |
6 | !   A 1                 a Q   q |
7 | "   B 2                 b R   r |
8 | #   C 3                 c S   s |
9 | $   D 4                 d T   t |
A | %   E 5                 e U   u |
B | &   F 6                 f V   v |
C | '   G 7                 g W   w |
D | (   H 8                 h X   x |
E | )   I 9                 i Y   y |
F | *   J :                 j Z   z |
   ---------------------------------
```

And we have our transformation that puts [0, 7] in our target charset.

Let's inverse it to get the transformation that puts our target charset in [0, 7]. Our SIMD sequence will need :
- `ADD -59`
- `XOR with (1 << 4) | (1 << 6)`
- `ADD -16`

Which is again just 3 SIMD instructions.

## A harder case : detecting '"{^'

Our previous solutions worked nicely because both `[]` and `{}` couples are on the same columns.

Sometimes, things do not turn out that nicely, and we can't just use only XOR and AND.

As an example, let's try to detect `("{^)` efficiently.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |       0 @ P ` p                 |
1 |     ! 1 A Q a q                 |
2 |     " 2 B R b r                 |
3 |     # 3 C S c s                 |
4 |     $ 4 D T d t                 |
5 |     % 5 E U e u                 |
6 |     & 6 F V f v                 |
7 |     ' 7 G W g w                 |
8 |     ( 8 H X h x                 |
9 |     ) 9 I Y i y                 |
A |     * : J Z j z                 |
B |     + ; K [ k {                 |
C |     , < L \ l |                 |
D |     - = M ] m }                 |
E |     . > N ^ n ~                 |
F |     / ? O _ o                   |
   ---------------------------------
```

They are all on different rows and columns, so we'll have to be a bit inventive here.

Let's throw a couple of dies and rely on randomness for once.

## Operation 2 : MUL

The multiplication operation is most likely supported by any SIMD engine, so we may as well try to do something with it.

One thing to keep in mind is that our operation has to be bijective, and that we cannot lose info.

The problem is that the multiplication itself may cause us to become non-bijective if we do not pay attention.

Indeed, the SIMD byte-wise multiplication will take two bytes as input, compute their multiplication, producing a `TWO BYTES` value as a result, and truncate it, only keeping the lower byte.

This is a problem, as we must ensure that the truncation does not cause an intrinsic loss of information.

Fortunately, maths tell us that as long as we multiply by a number which is prime with our numerical base(256), we're fine.

Since 256 is solely a multiple of 2, in practice, this just means that if we multiply by an odd number, we're fine.

Now that this is addressed, the reason why the MUL operation is interesting is that it will essentially reorder our base ascii set in a relatively random way. By random I don't mean unpredictable, but relatively non regular. I'll let you be the judge of it : here is a (long) view of the 128 possible bijective reorderings of our ascii charset. On the right is the full reordered set, and on the left appear only the three characters `"{^' that we are interested in.

{{< collapsible-code path="content/asm/trk_1_set/mul_spc.log" lang="c" title="All our possible reorderings." >}}

Now apart from the relative pleasure one can find by scrolling down and seeing the wave-like patterns move, there is a purpose in showing you this.

## Solving our problem

Among all those variations, there are some that have two of our target characters on the same column, and that makes them potential candidates for our XOR method.

In particular, let's take a look at variation 29 :

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |                                 |
1 |                                 |
2 |                                 |
3 |                                 |
4 |                                 |
5 |                                 |
6 |               ^                 |
7 |               {                 |
8 |                                 |
9 |                                 |
A | "                               |
B |                                 |
C |                                 |
D |                                 |
E |                                 |
F |                                 |
   ---------------------------------
```

We have two adjacent characters which is great ! We just need to get the other closer.

Let's first flip bit 6 which will swap (aligned) blocks of 4 columns.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |                                 |
1 |                                 |
2 |                                 |
3 |                                 |
4 |                                 |
5 |                                 |
6 |       ^                         |
7 |       {                         |
8 |                                 |
9 |                                 |
A |         "                       |
B |                                 |
C |                                 |
D |                                 |
E |                                 |
F |                                 |
   ---------------------------------
```

Now the characters are in a close range but it is still a big range, 21 wide.

We'll use the xor again to flip bit 3, which this time, will swap (aligned) blocks of _rows_.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 |                                 |
1 |                                 |
2 |         "                       |
3 |                                 |
4 |                                 |
5 |                                 |
6 |                                 |
7 |                                 |
8 |                                 |
9 |                                 |
A |                                 |
B |                                 |
C |                                 |
D |                                 |
E |       ^                         |
F |       {                         |
   ---------------------------------
```

Now the situation is ideal. We just need to do our usual add, this time with offset 62, to move chars in the [0, 7] range.

```
    0 1 2 3 4 5 6 7 8 9 A B C D E F
   ---------------------------------
0 | ^                               |
1 | {                               |
2 |                                 |
3 |                                 |
4 | "                               |
5 |                                 |
6 |                                 |
7 |                                 |
8 |                                 |
9 |                                 |
A |                                 |
B |                                 |
C |                                 |
D |                                 |
E |                                 |
F |                                 |
   ---------------------------------
```

But remember that we still have a missing step, as we need to invert this sequence of operations to find our desired transformation.

Now since every odd numbers are prime with 256, maths tell us that that every odd number has an inverse through the MUL operation, aka for every odd number X in [0, 255] there is another (odd) number in [0, 255] that for every number N of [0, 255] `MUL(MUL(X, N), Y) == N`;

Euclide's algorithm provides us with a convoluted way to compute the inverse by solving diophantine equations but frankly I didn't want to lose sanity over implementing that, so I just generated the 128 output diagrams of `(N) -> MUL(MUL(N, 29), Y)` for every odd number `Y` of `[1, 255]` and looked at the one that gave our original charset, and it turns out that the inverse of 29 is 53.

We now have our final procedure :
- `ADD -62`
- `XOR (1 << 3) | (1 << 6)`
- `MUL 53`

Since we did not have to do any ADD-related adjustment between the MUL and XOR, we again just need three instructions to perform the transformation.

