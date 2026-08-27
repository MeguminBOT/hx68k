OUTPUT_ARCH(m68k)
SEARCH_DIR(.)

MEMORY
{
	rom (rx) : ORIGIN = 0x00000000, LENGTH = 0xE0000000
	ram (rwx) : ORIGIN = 0xE0FF0000, LENGTH = 0x00010000
}

PROVIDE (__stack = 0xE1000000);

SECTIONS
{
	.text 0x00000000 :
	{
		KEEP(*(.text.keepboot))
		*(.text.*)
		*(.text)

		. = ALIGN(0x4);
		*(.rodata .rodata.*)

		_etext = .;
		*(.rodata_bin)
		*(.rodata_binf)
	} > rom

	_stext = SIZEOF (.text);

	.data 0xE0FF0000 : AT ( ADDR (.text) + SIZEOF (.text) )
	{
		*(.data .data.*)
		*(.ramprog .ramprog.*)
		_edata = .;
	} > ram

	_sdata = SIZEOF (.data);

	.bss 0xE0FF0000 + SIZEOF (.data) :
	{
		_start = . ;
		*(.bss .bss.*)
		*(COMMON)
		_bend = . ;
	} > ram

	.stab 0 (NOLOAD) : { *(.stab) }
	.stabstr 0 (NOLOAD) : { *(.stabstr) }
	.eh_frame 0 (NOLOAD) : { *(.eh_frame) }
	.comment 0 (NOLOAD) : { *(.comment) }
}
