(lldb) dis -n ns_js_fsk_arr
prc`ns_js_fsk_arr:
0x45cdcc <+0>:   stp    x29, x30, [sp, #-0x20]!
0x45cdd0 <+4>:   mov    x1, x0
0x45cdd4 <+8>:   add    x0, x0, #0x1
0x45cdd8 <+12>:  mov    x29, sp
0x45cddc <+16>:  stp    x19, x20, [sp, #0x10]
0x45cde0 <+20>:  adrp   x20, 52
0x45cde4 <+24>:  add    x20, x20, #0x5a0 ; ns_js_fsk_arr_tbl
0x45cde8 <+28>:  ldur   x2, [x1, #0x1]
0x45cdec <+32>:  ldur   x3, [x1, #0x9]
0x45cdf0 <+36>:  and    w1, w2, #0xff
0x45cdf4 <+40>:  ldrsb  w19, [x20, w1, sxtw]
0x45cdf8 <+44>:  adds   w19, w19, #0x1
0x45cdfc <+48>:  b.eq   0x45cfcc       ; <+512> at js.c:663:3
0x45ce00 <+52>:  cmp    w1, #0x22
0x45ce04 <+56>:  b.eq   0x45cfe4       ; <+536> at js.c:663:3
0x45ce08 <+60>:  ubfx   w5, w2, #8, #8
0x45ce0c <+64>:  add    x1, x0, #0x1
0x45ce10 <+68>:  ldrsb  w4, [x20, w5, sxtw]
0x45ce14 <+72>:  adds   w19, w19, w4
0x45ce18 <+76>:  b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce1c <+80>:  cmp    w5, #0x22
0x45ce20 <+84>:  b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ce24 <+88>:  ubfx   w5, w2, #16, #8
0x45ce28 <+92>:  add    x1, x0, #0x2
0x45ce2c <+96>:  ldrsb  w4, [x20, w5, sxtw]
0x45ce30 <+100>: adds   w19, w19, w4
0x45ce34 <+104>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce38 <+108>: cmp    w5, #0x22
0x45ce3c <+112>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ce40 <+116>: lsr    w5, w2, #24
0x45ce44 <+120>: add    x1, x0, #0x3
0x45ce48 <+124>: ldrsb  w4, [x20, w5, sxtw]
0x45ce4c <+128>: adds   w19, w19, w4
0x45ce50 <+132>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce54 <+136>: cmp    w5, #0x22
0x45ce58 <+140>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ce5c <+144>: ubfx   x5, x2, #32, #8
0x45ce60 <+148>: add    x1, x0, #0x4
0x45ce64 <+152>: ldrsb  w4, [x20, w5, sxtw]
0x45ce68 <+156>: adds   w19, w19, w4
0x45ce6c <+160>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce70 <+164>: cmp    w5, #0x22
0x45ce74 <+168>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ce78 <+172>: ubfx   x5, x2, #40, #8
0x45ce7c <+176>: add    x1, x0, #0x5
0x45ce80 <+180>: ldrsb  w4, [x20, w5, sxtw]
0x45ce84 <+184>: adds   w19, w19, w4
0x45ce88 <+188>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45ce8c <+192>: cmp    w5, #0x22
0x45ce90 <+196>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ce94 <+200>: ubfx   x5, x2, #48, #8
0x45ce98 <+204>: add    x1, x0, #0x6
0x45ce9c <+208>: ldrsb  w4, [x20, w5, sxtw]
0x45cea0 <+212>: adds   w19, w19, w4
0x45cea4 <+216>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cea8 <+220>: cmp    w5, #0x22
0x45ceac <+224>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ceb0 <+228>: lsr    x4, x2, #56
0x45ceb4 <+232>: add    x1, x0, #0x7
0x45ceb8 <+236>: mov    x2, x4
0x45cebc <+240>: ldrsb  w4, [x20, x4]
0x45cec0 <+244>: adds   w19, w19, w4
0x45cec4 <+248>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cec8 <+252>: cmp    x2, #0x22
0x45cecc <+256>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ced0 <+260>: and    w4, w3, #0xff
0x45ced4 <+264>: add    x1, x0, #0x8
0x45ced8 <+268>: ldrsb  w2, [x20, w4, sxtw]
0x45cedc <+272>: adds   w19, w19, w2
0x45cee0 <+276>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cee4 <+280>: cmp    w4, #0x22
0x45cee8 <+284>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45ceec <+288>: ubfx   w4, w3, #8, #8
0x45cef0 <+292>: add    x1, x0, #0x9
0x45cef4 <+296>: ldrsb  w2, [x20, w4, sxtw]
0x45cef8 <+300>: adds   w19, w19, w2
0x45cefc <+304>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf00 <+308>: cmp    w4, #0x22
0x45cf04 <+312>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf08 <+316>: ubfx   w4, w3, #16, #8
0x45cf0c <+320>: add    x1, x0, #0xa
0x45cf10 <+324>: ldrsb  w2, [x20, w4, sxtw]
0x45cf14 <+328>: adds   w19, w19, w2
0x45cf18 <+332>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf1c <+336>: cmp    w4, #0x22
0x45cf20 <+340>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf24 <+344>: lsr    w4, w3, #24
0x45cf28 <+348>: add    x1, x0, #0xb
0x45cf2c <+352>: ldrsb  w2, [x20, w4, sxtw]
0x45cf30 <+356>: adds   w19, w19, w2
0x45cf34 <+360>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf38 <+364>: cmp    w4, #0x22
0x45cf3c <+368>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf40 <+372>: ubfx   x4, x3, #32, #8
0x45cf44 <+376>: add    x1, x0, #0xc
0x45cf48 <+380>: ldrsb  w2, [x20, w4, sxtw]
0x45cf4c <+384>: adds   w19, w19, w2
0x45cf50 <+388>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf54 <+392>: cmp    w4, #0x22
0x45cf58 <+396>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf5c <+400>: ubfx   x4, x3, #40, #8
0x45cf60 <+404>: add    x1, x0, #0xd
0x45cf64 <+408>: ldrsb  w2, [x20, w4, sxtw]
0x45cf68 <+412>: adds   w19, w19, w2
0x45cf6c <+416>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf70 <+420>: cmp    w4, #0x22
0x45cf74 <+424>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf78 <+428>: ubfx   x4, x3, #48, #8
0x45cf7c <+432>: add    x1, x0, #0xe
0x45cf80 <+436>: ldrsb  w2, [x20, w4, sxtw]
0x45cf84 <+440>: adds   w19, w19, w2
0x45cf88 <+444>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cf8c <+448>: cmp    w4, #0x22
0x45cf90 <+452>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cf94 <+456>: lsr    x2, x3, #56
0x45cf98 <+460>: add    x1, x0, #0xf
0x45cf9c <+464>: mov    x3, x2
0x45cfa0 <+468>: ldrsb  w2, [x20, x2]
0x45cfa4 <+472>: adds   w19, w19, w2
0x45cfa8 <+476>: b.eq   0x45cfd0       ; <+516> at js.c:666:1
0x45cfac <+480>: cmp    x3, #0x22
0x45cfb0 <+484>: b.eq   0x45cfe0       ; <+532> at js.c:663:3
0x45cfb4 <+488>: add    x0, x0, #0x10
0x45cfb8 <+492>: ldp    x2, x3, [x0]
0x45cfbc <+496>: and    w1, w2, #0xff
0x45cfc0 <+500>: ldrsb  w4, [x20, w1, sxtw]
0x45cfc4 <+504>: adds   w19, w19, w4
0x45cfc8 <+508>: b.ne   0x45ce00       ; <+52> at js.c:663:3
0x45cfcc <+512>: mov    x1, x0
0x45cfd0 <+516>: ldp    x19, x20, [sp, #0x10]
0x45cfd4 <+520>: add    x0, x1, #0x1
0x45cfd8 <+524>: ldp    x29, x30, [sp], #0x20
0x45cfdc <+528>: ret
0x45cfe0 <+532>: mov    x0, x1
0x45cfe4 <+536>: bl     0x44e840       ; ns_js_fsk_str
0x45cfe8 <+540>: b      0x45cfb8       ; <+492> at js.c:662:12

