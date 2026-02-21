.section .text
.global _start

_start:
  li x1, -4
  li x2, 4
  and x3, x1, x2
  wfi
