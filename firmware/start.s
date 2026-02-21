.section .text
.global _start

_start:
  li x1, -2
  li x2, -3
  add x3, x1, x2
  wfi
