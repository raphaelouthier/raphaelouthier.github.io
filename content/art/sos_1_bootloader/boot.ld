MEMORY {
  SRAM(rwx) : ORIGIN = 0x20041f00, LENGTH = 0xfe
}
SECTIONS {
  .stage2 ORIGIN(SRAM) : {
    KEEP(*(.stage2))
  } > SRAM
}
