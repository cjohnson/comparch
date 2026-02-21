.section .text
.global _start

_start:
  li x1, -2
  srai x2, x1, 1
  wfi
