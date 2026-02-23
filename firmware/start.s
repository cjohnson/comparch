.section .text
.global _start

_start:
  li x5, 2
  li x6, 3
  bltu x5, x6, _L1
_L0:
  li x7, 1
  j _L2
_L1:
  li x7, 2
_L2:
  wfi
