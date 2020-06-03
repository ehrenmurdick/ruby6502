here's an example asm file. It's not quite normal asm as I havent gotten there
yet but its a dsl for ruby that has the opcodes

```code
lda_im 0xfe
sta_ab 0x1010

lda_im 0x10
sta_ab 0x0
lda_im 0x10
sta_ab 0x1

lda_iz 0x0

brk
```

and heres the output. every group of lines between the dashes is one clock
tick, and the registers and memory at that point

```code
6502 pc=0 run=t

a=00 x=00 y=00
<    b  >
{}
-------
6502 pc=1 run=t
lda_im fe
a=fe x=00 y=00
<    b n>
{}
-------
6502 pc=2 run=t
sta_ab 1010
a=fe x=00 y=00
<    b n>
{"1010"=>"fe"}
-------
6502 pc=3 run=t
lda_im 10
a=10 x=00 y=00
<    b  >
{"1010"=>"fe"}
-------
6502 pc=4 run=t
sta_ab 0
a=10 x=00 y=00
<    b  >
{"1010"=>"fe", "0"=>"10"}
-------
6502 pc=5 run=t
lda_im 10
a=10 x=00 y=00
<    b  >
{"1010"=>"fe", "0"=>"10"}
-------
6502 pc=6 run=t
sta_ab 1
a=10 x=00 y=00
<    b  >
{"1010"=>"fe", "0"=>"10", "1"=>"10"}
-------
6502 pc=7 run=t
lda_iz 0
a=fe x=00 y=00
<    b n>
{"1010"=>"fe", "0"=>"10", "1"=>"10"}
-------
6502 pc=8 run=f
brk 
a=fe x=00 y=00
<    b n>
{"1010"=>"fe", "0"=>"10", "1"=>"10"}
-------
```
