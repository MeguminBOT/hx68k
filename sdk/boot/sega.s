    .section .text.keepboot
    .globl  rom_header
    .org    0x00000000

_Vectors:
    dc.l    __stack
    dc.l    _Entry
    dc.l    _Error, _Error, _Error, _Error, _Error, _Error
    dc.l    _Error, _Error, _Error, _Error
    dc.l    _Error, _Error, _Error, _Error
    dc.l    _Error, _Error, _Error, _Error
    dc.l    _Error, _Error, _Error, _Error
    dc.l    _Error
    dc.l    _Ignore
    dc.l    _Ext
    dc.l    _Ignore
    dc.l    _Horizontal
    dc.l    _Ignore
    dc.l    _Vertical
    dc.l    _Ignore
    dc.l    _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore
    dc.l    _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore
    dc.l    _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore
    dc.l    _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore, _Ignore

rom_header:
    .incbin "out/rom_header.bin", 0, 0x100

_Entry:
    move    #0x2700, %sr

    move.l  #0xA11100, %a0
    move.w  #0x0100, %d0
    move.w  %d0, (%a0)
    move.w  %d0, 0x0100(%a0)

    tst.l   0xA10008
    bne.s   _Warm
    tst.w   0xA1000C
    bne.s   _Warm

    move.b  -0x10FF(%a0), %d0
    andi.b  #0x0F, %d0
    beq.s   _Warm
    move.l  #0x53454741, 0x2F00(%a0)

_Warm:
    lea     0xFF0000, %a1
    move.w  #0x3FFF, %d0
    moveq   #0, %d1
_Wipe:
    move.l  %d1, (%a1)+
    dbra    %d0, _Wipe

    move.l  #_sdata, %d0
    lsr.l   #1, %d0
    beq.s   _Ready
    subq.l  #1, %d0
    move.l  #_stext, %a0
    lea     0xFF0000, %a1
_Copy:
    move.w  (%a0)+, (%a1)+
    dbra    %d0, _Copy

_Ready:
    jmp     md_start

_Vertical:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    jsr     md_vertical
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rte

_Horizontal:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    jsr     md_horizontal
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rte

_Ext:
    movem.l %d0-%d1/%a0-%a1, -(%sp)
    jsr     md_external
    movem.l (%sp)+, %d0-%d1/%a0-%a1
    rte

_Error:
    move    #0x2700, %sr
    stop    #0x2700
    bra.s   _Error

_Ignore:
    rte

    .globl  md_interrupts_on
md_interrupts_on:
    move    #0x2000, %sr
    rts

    .globl  md_interrupts_off
md_interrupts_off:
    move    #0x2700, %sr
    rts
