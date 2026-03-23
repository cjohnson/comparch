.section .text
.global _start

_start:
  li x1, 1
  li x2, 2
  sltu x3, x1, x2
  sltu x4, x2, x1
