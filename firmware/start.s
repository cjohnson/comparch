.section .text
.global _start

_start:
  add x1, zero, 1
  auipc x1, 0
  auipc x2, 0
  wfi
