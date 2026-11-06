.text
.global _start
.global checkpoint
_start:
    li a0, 37
checkpoint:
    nop
    li a0, 0
    li a7, 93
    ecall
