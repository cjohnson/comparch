.section .text
.global _start

_start:
  li x1, -4
  li x2, 1
  srl x3, x1, x2
  sra x4, x1, x2
  or x5, x1, x2
  and x6, x1, x2
