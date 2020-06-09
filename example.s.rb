jmp_ab :go

label :foo
ina
rts

label :go
lda_im 0xa6
jsr_ab :foo
brk

