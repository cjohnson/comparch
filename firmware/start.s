.section .text
.global _start

_start:
  jal ra, foo
  addi x6, x5, 1
  wfi

foo:
  li x5, 23
  jalr zero, ra, 0
