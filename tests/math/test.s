.equ SYS_WRITE, 64

.text
.align 2
.globl _start
_start:

    li x1, 0xbb
    li x2, 0x555
    li x3, 0x01
    li x4, 0xaaa

    la x14, const_buffer
    lw x5, 0(x14)
    ld x6, 0(x14)
    addw x7, x5, x6

pass:
    li t0, 1
    sd t0, tohost, t1
    ebreak
1:  j 1b

syscall:
    la t0, syscall_buffer
    sd a0, 0(t0)
    sd a1, 8(t0)
    sd a2, 16(t0)
    sd a3, 24(t0)
    sd a4, 32(t0)
    sd a5, 40(t0)
    sd a6, 48(t0)
    sd a7, 56(t0)

    la t1, tohost
    sd t0, (t1)

    la t1, fromhost
1:  ld t2, (t1)
    beqz t2, 1b
    sd zero, (t1)

    ld a0, (t0)
    ret

.data
msg: .string "hello\n"

.align 3
syscall_buffer: .skip 64

.align 4
const_buffer:
.dword 0xaaaaaaaaaaaaaaaa
.skip 64

.section .tohost,"aw",@progbits
.globl tohost
.globl fromhost
.align 3
tohost: .dword 0
fromhost: .dword 0
