.section .text
.global _start

_start:
  li x5, 1
  li x6, 1
  bne x5, x6, _L1
_L0:
  li x7, 1
  j _L2
_L1:
  li x7, 2
_L2:
  wfi
