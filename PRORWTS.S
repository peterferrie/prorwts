;open/read/write binary file in ProDOS filesystem
;copyright (c) Peter Ferrie 2013-16
!cpu 6502
!to "prorwts",plain
*=$800

                enable_floppy = 0       ;set to 1 to enable floppy drive support
                override_adr = 0        ;set to 1 to require an explicit load address
                enable_write = 0        ;set to 1 to enable write support
                                        ;file must exist already and its size cannot be altered
                                        ;writes occur in multiples of block size (256 bytes for floppy, 512 bytes for HDD)
                allow_multi  = 1        ;set to 1 to allow multiple floppies
                allow_subdir = 0        ;set to 1 to allow opening subdirectories to access files
                might_exist  = 0        ;set to 1 if file is not known to always exist already
                                        ;makes use of status to indicate success or failure
                allow_aux    = 0        ;set to 1 to allow read/write directly to/from aux memory
                load_high    = 0        ;load into banked RAM instead of main RAM
                lc_bank      = 1        ;load into specified bank (1 or 2) if load_high=1

!if enable_floppy=1 {
                tmpsec    = $3c
                reqsec    = $3d
} ;enable_floppy
                A1L       = $3c
                A1H       = $3d
                A2L       = $3e
                A2H       = $3f
!if enable_write=1 {
                A3L       = $40
                A3H       = $41
} ;enable_write
!if enable_floppy=1 {
                curtrk    = $40
} ;enable_floppy

                command   = $42         ;ProDOS constant
                unit      = $43         ;ProDOS constant
                adrlo     = $44         ;ProDOS constant
                adrhi     = $45         ;ProDOS constant
                bloklo    = $46         ;ProDOS constant
                blokhi    = $47         ;ProDOS constant

                secsize   = $46
                secsize1  = $47
                secsize2  = $48

!if might_exist=1 {
                status    = $f3         ;returns non-zero on error
}
!if allow_aux=1 {
                auxreq    = $f4         ;set to 1 to read/write aux memory, else main memory is used
}
                sizelo    = $f5         ;must set if writing
                sizehi    = $f6         ;must set if writing
                entries   = $f7         ;total number of entries
                reqcmd    = $f8         ;used if enable_write=1, 1=read, 2=write; if allow_multi=1, bit 7 selects drive
                ldrlo     = $f9         ;used if override_adr=1
                ldrhi     = $fa         ;used if override_adr=1
                namlo     = $fb
                namhi     = $fc
!if enable_floppy=1 {
                step      = $fd         ;state for stepper motor
                tmptrk    = $fe         ;temporary copy of current track
                phase     = $ff         ;current phase for seek
  !if enable_write=1 {
    !if load_high=1 {
                reloc     = $d000
                dirbuf    = $d400
                encbuf    = $d600
    } else { ;load_high
                reloc     = $bc00
                dirbuf    = $ba00
                encbuf    = $b900
    } ;load_high
  } else { ;enable_write
    !if load_high=1 {
                reloc     = $d000
                dirbuf    = $d300
    } else { ;load_high
                reloc     = $bd00
                dirbuf    = $bb00
    } ;load_high
  } ;enable_write
} else { ;enable_floppy
  !if load_high=1 {
                reloc     = $d000
                dirbuf    = $d200
  } else { ;load_high
                reloc     = $be00
                dirbuf    = $bc00
  } ;load_high
} ;enable_floppy

init            jsr $fe93
                jsr $fe89
                lda $bf30
                sta x80_parms+1
                sta unrunit+1
                and #$70
                pha
!if enable_floppy=1 {
                ora #$80
                sta unrseek+1
                ora #8
                sta unrdrvoff+1
                tax
                inx
                stx unrdrvon+1
                inx
  !if allow_multi=1 {
                stx unrdrvsel+1
  } ;allow_multi
                inx
                inx
                stx unrread1+1
                stx unrread2+1
                stx unrread3+1
  !if enable_write=1 {
                stx unrread4+1
                stx unrread5+1
                stx unrread6+1
                stx unrread7+1
                stx unrread8+1
                inx
                stx unrlatch1+1
                stx unrlatch2+1
                stx unrlatch3+1
                stx unrlatch4+1
                inx
                stx unrlatchin1+1
                stx unrlatchin2+1
                inx
                stx unrlatchout+1
  } ;enable_write
} ;enable_floppy
                ldx #1
                stx namlo
                inx
                stx namhi

                jsr $bf00
                !byte $c7
                !word c7_parms
                ldx $200
                dex
                stx sizelo
                bmi plus05

readblock       jsr $bf00
                !byte $80
                !word x80_parms

                sta A2L
                lda #<(readbuff+4)
                sta A1L
                lda #>(readbuff+4)
                sta A1H
inextent        ldy #0
                lda (A1L), y
                pha
                and #$d0

                ;watch for subdirectory entries

                cmp #$d0
                bne plus01

                lda (A1L), y
                and #$0f
                tax
                iny
minus01         lda (A1L), y
                cmp (namlo), y
                beq ifoundname

                ;match failed, move to next directory in this block, if possible

minus02
plus01          pla
                clc
                lda A1L
                adc #$27
                sta A1L
                bcc plus02

                ;there can be only one page crossed, so we can increment instead of adc

                inc A1H
plus02          inc A2L
                lda A2L
                cmp #$0d
                bcc inextent

                ;read next directory block when we reach the end of this block

                ldy readbuff+2
                ldx readbuff+3
                bcs plus03

ifoundname      iny
                dex
                bne minus01
                lda (namlo), y
                cmp #'/'
                bne minus02
                tya
                eor #$ff
                adc sizelo
                sta sizelo
                clc
                tya
                adc namlo
                sta namlo
                pla
                and #$20
                bne plus04
                ldy #$12
                lda (A1L), y
                tax
                dey
                lda (A1L), y
                tay
!if enable_floppy=1 {
                sty unrblocklo+1
                stx unrblockhi+1
} ;enable_floppy
                sty unrhddblocklo+1
                stx unrhddblockhi+1
plus03          sty x80_parms+4
                stx x80_parms+5
plus04          lda sizelo
                bne readblock

plus05          pla
                lsr
                lsr
                lsr
                lsr
                ora #$c0
                sta slot+2
                sta unrentry+2
!if enable_floppy=1 {
                ldx #>unrelocdsk
                ldy #<unrelocdsk
slot            lda $cfff
                sta unrentry+1
                php
                beq copydrv
                ldx #>unrelochdd
                ldy #<unrelochdd

copydrv         stx A1H
                sty A1L
                inx
                stx A2H
                sty A2L
  !if enable_write=1 {
                inx
                stx A3H
                sty A3L
  } ;enable_write
  !if load_high=1 {
    !if lc_bank=1 {
                lda $c089
                lda $c089
    } else { ;lc_bank
                lda $c081
                lda $c081
    } ;lc_bank
  } ;load_high
                ldy #0
minus03         lda (A1L), y
                sta reloc, y
                lda (A2L), y
                sta reloc+$100, y
  !if enable_write=1 {
                lda (A3L), y
                sta reloc+$200, y
  } ;enable_write
                iny
                bne minus03
                plp
                bne plus07
                ldx #$16
minus04         stx A1L
                txa
                asl
                bit A1L
                beq plus06
                ora A1L
                eor #$ff
                and #$7e
minus05         bcs plus06
                lsr
                bne minus05
                tya
                sta nibtbl-$16, x
  !if enable_write=1 {
                txa
                ora #$80
                sta xlattbl, y
  } ;enable_write
                iny
plus06          inx
                bpl minus04
plus07          rts
} else { ;enable_floppy
slot            lda $cfff
                sta unrentry+1
  !if load_high=1 {
    !if lc_bank=1 {
                lda $c089
                lda $c089
    } else { ;lc_bank
                lda $c081
                lda $c081
    } ;lc_bank
  } ;load_high
                ldy #0
minus06         lda unrelochdd, y
                sta reloc, y
                lda unrelochdd+$100, y
                sta reloc+$100, y
                iny
                bne minus06
                rts
} ;enable_floppy

c7_parms        !byte 1
                !word $200

x80_parms       !byte 3, $d1
                !word readbuff, 2

!if enable_floppy=1 {
unrelocdsk
!pseudopc reloc {

opendir         ;read volume directory key block
  !if enable_write=1 {
                ldx #1
                stx command
                dex
  } else { ;enable_write
                ldx #0
  } ;enable_write
                stx adrlo
                stx secsize1

  !if allow_multi=1 {
                asl reqcmd
                bcc seldrive
                inx
seldrive        lsr reqcmd
unrdrvsel=unrelocdsk+(*-reloc)
                lda $c0ea, x
  } ;allow_multi

unrblocklo=unrelocdsk+(*-reloc)
                lda #2
unrblockhi=unrelocdsk+(*-reloc)
                ldx #0
                jsr readdirsec

                ;include volume directory header in count

readdir
  !if might_exist=1 {
                ldx dirbuf+37
                inx
                stx entries
  }
  !if allow_subdir=1 {
                ldy #0
  } ;allow_subdir
  !if might_exist=1 {
                sty status
                sty A2H
  }
firstent        sty A2L
                lda #<(dirbuf+4)
                sta A1L
                lda #>(dirbuf+4)
                sta A1H
nextent         ldy #0
                lda (A1L), y
                and #$f0

  !if might_exist=1 {
                ;skip deleted entries without counting

                beq plus09
  } ;might_exist

  !if allow_subdir=1 {
                ;subdirectory entries are seedlings
                ;but we need to distinguish between them later

                cmp #$d0
                beq savetype
  } ;allow_subdir

                ;watch for seedling and saplings only

                cmp #$30
                bcs plus08

                ;remember type

savetype
  !if allow_subdir=1 {
                asl
                asl
  } else { ;allow_subdir
                cmp #$20
  } ;allow_subdir
                php

                ;match name lengths before attempting to match names

                lda (A1L), y
                and #$0f
                tax
                inx
                !byte $2c
minus07         lda (A1L), y
                cmp (namlo), y
                beq foundname

                ;match failed, check if any directory entries remain

                plp
plus08
  !if might_exist=1 {
                inc A2H
                lda A2H
                cmp entries

                ;lock if entry not found

                bne plus09
                inc status
                rts
  } ;might_exist

                ;move to next directory in this block, if possible

plus09          clc
                lda A1L
                adc #$27
                sta A1L
                bcc plus10

                ;there can be only one page crossed, so we can increment instead of adc

                inc A1H
plus10          inc A2L
                lda A2L
                cmp #$0d
                bcc nextent

                ;read next directory block when we reach the end of this block

                lda dirbuf+2
                ldx dirbuf+3
                jsr readdirsec
                beq firstent

foundname       iny
                dex
                bne minus07

  !if enable_write=1 {
                ldy reqcmd
                dey
                php
                beq plus12

                ;round requested size up to nearest sector
                ;and cache requested size if writing

                ldx sizehi
                beq plus11
                lda sizelo
                beq plus12
plus11          inx
plus12 
  } ;enable_write

                ;cache EOF (file size)

                ldy #$15
                lda (A1L), y
                sta sizelo
                iny
                lda (A1L), y
                sta sizehi

  !if enable_write=1 {
                plp
                beq plus15

                ;round file size up to nearest sector
                ;and check against requested size if writing

                tay
                beq plus13
                lda sizelo
                beq plus14
                ldy #0
plus13          sty sizelo
                inc sizehi

                ;set read size to min(length, requested size)

plus14          cpx sizehi
                bcs plus15
                stx sizehi
plus15 
  } ;enable_write

                ;cache AUX_TYPE (load offset for binary files)

  !if override_adr=0 {
    !if allow_subdir=1 {
                pla
                tax
    } else { ;allow_subdir
                plp
    } ;allow_subdir
                ldy #$1f
                lda (A1L), y
                pha
                iny
                lda (A1L), y
                pha
    !if allow_subdir=1 {
                txa
                pha
    } ;allow_subdir
  } ;override_adr

                ;cache KEY_POINTER (loaded backwards)

                ldy #$12
                lda (A1L), y
                tax
                sta dirbuf+256
                dey
                lda (A1L), y
                sta dirbuf
                ldy #0
                sty entries

                ;read index block in case of sapling

  !if allow_subdir=1 {
                plp
                bpl plus16
                php
                jsr readdirsec
                plp
  } else { ;allow_subdir
    !if override_adr=1 {
                plp
    } ;override_adr
                bcc plus16
                jsr readdirsec
  } ;allow_subdir

                ;restore load offset

plus16
  !if override_adr=1 {
                ldx ldrhi
                lda ldrlo
  } else { ;override_adr
                pla
                tax
                pla
  } ;override_adr
  !if enable_write=1 {
                ldy reqcmd
  } ;enable_write

  !if allow_subdir=1 {
                ;check file type and fake size and load address for subdirectories

                bcc plus17
                ldy #2
                sty sizehi
    !if enable_write=1 {
                dey
    } ;enable_write
                ldx #>dirbuf
                lda #<dirbuf
plus17
  } ;allow_subdir
  !if enable_write=1 {
                sty command
  } ;enable_write
                sta adrlo
                stx adrhi

  !if allow_aux=1 {
                ldx auxreq
                sta $c002, x
                sta $c004, x
  }

                ;set read size to min(length, $200)

readfile        lda sizelo
                ldx sizehi
                cpx #2
                bcc plus18
  !if enable_write=1 {
                lda #0
  } else { ;enable_write
    !if allow_subdir=1 {
                lda #0
    } else { ;allow_subdir
                tya
    } ;allow_subdir
  } ;enable_write
                ldx #2
plus18          sta secsize1
                stx secsize2

                ;fetch data block and read it

                ldy entries
                inc entries
                lda dirbuf, y
                ldx dirbuf+256, y
                jsr seekread

                ;if low count is non-zero then we are done
                ;(can happen only for partial last block)

                lda secsize1
                bne readdone

                ;if count is $1xx then we are done
                ;(can happen only for partial last block)

                dec sizehi
                beq readdone

                ;loop while size-$200 is non-zero

                dec sizehi
                inc adrhi
                lda sizehi
                ora sizelo
                bne readfile

unrdrvoff=unrelocdsk+(*-reloc)
readdone        lda $c0e8
  !if allow_aux=1 {
                sta $c002
                sta $c004
  }
seekret         rts

                ;no tricks here, just the regular stuff

seek            sty step
                asl phase
                txa
                asl
copy_cur        tax
                sta tmptrk
                sec
                sbc phase
                beq seekret
                bcs plus19
                eor #$ff
                inx
                bcc plus20
plus19          sbc #1
                dex
plus20          cmp step
                bcc plus21
                lda step
plus21          cmp #8
                bcs plus22
                tay
                sec
plus22          txa
                pha
                ldx step1, y
                bne plus23
minus08         clc
                lda tmptrk
                ldx step2, y
plus23          stx tmpsec
                and #3
                rol
                tax
                lsr
unrseek=unrelocdsk+(*-reloc)
                lda $c0e0, x
minus09         ldx #$13
minus10         dex
                bne minus10
                dec tmpsec
                bne minus09
                bcs minus08
                pla
                inc step
                bne copy_cur

step1           !byte 1, $30, $28, $24, $20, $1e, $1d, $1c
step2           !byte $70, $2c, $26, $22, $1f, $1e, $1d, $1c

readadr
minus11         jsr readd5aa
                cmp #$96
                bne minus11
                ldy #3
minus12         sta curtrk
                jsr readnib
                rol
                sta tmpsec
                jsr readnib
                and tmpsec
                dey
                bne minus12
                rts

readd5aa
minus13         jsr readnib
minus14         cmp #$d5
                bne minus13
                jsr readnib
                cmp #$aa
                bne minus14
                tay                    ;we need Y=#$AA later

readnib
unrread3=unrelocdsk+(*-reloc)
minus15         lda $c0ec
                bpl minus15
                rts

readdirsec
unrdrvon=unrelocdsk+(*-reloc)
                ldy $c0e9
                ldy #2
                sty secsize2
                ldy #>dirbuf
                sty adrhi

                ;convert block number to track/sector

seekread        pha
                and #7
                cmp #4
                and #3
                php
                asl
                plp
                rol
                sta reqsec
                txa
                lsr
                pla
                ror
                lsr
                lsr
                sta phase

                ;set read size to min(first size, $100) and then read address

                ldy #0
                lda secsize2
                bne plus24
                ldy secsize1
plus24          sty secsize
                dec secsize2
                jsr readadr

                ;if track does not match, then seek

                ldx curtrk
                cpx phase
                beq checksec
                jsr seek

                ;force sector mismatch

                lda #$ff

                ;match or read sector

checksec        jsr cmpsec

                ;return if less than one sector requested

                tya
                bne readret

                ;return if only one sector requested

                lda secsize1
                cmp secsize2
                beq readret
                sta secsize
                inc adrhi
                inc reqsec
                inc reqsec

cmpsec
  !if enable_write=1 {
                ldy command
                dey
                bne encsec
  } ;enable_write
cmpsecrd        cmp reqsec
                beq readdata
                jsr readadr
                beq cmpsecrd

                ;read sector data

readdata        jsr readd5aa
                eor #$ad                ;zero A if match
;;                bne *                   ;lock if read failure
unrread1=unrelocdsk+(*-reloc)
minus16         ldx $c0ec
                bpl minus16
                eor nibtbl-$96, x
                sta bit2tbl-$aa, y
                iny
                bne minus16
unrread2=unrelocdsk+(*-reloc)
minus17         ldx $c0ec
                bpl minus17
                eor nibtbl-$96, x
                sta (adrlo), y          ;the real address
                iny
                cpy secsize
                bne minus17
                ldy #0
minus18         ldx #$a9
minus19         inx
                beq minus18
                lda (adrlo), y
                lsr bit2tbl-$aa, x
                rol
                lsr bit2tbl-$aa, x
                rol
                sta (adrlo), y
                iny
                cpy secsize
                bne minus19
readret         rts

  !if enable_write=1 {
encsec          iny
minus20         ldx #$aa
minus21         dey
                lda (adrlo), y
                lsr
                rol bit2tbl-$aa, x
                lsr
                rol bit2tbl-$aa, x
                sta encbuf, y
                lda bit2tbl-$aa, x
                and #$3f
                sta bit2tbl-$aa, x
                inx
                bne minus21
                tya
                bne minus20

cmpsecwr        jsr readadr
                cmp reqsec
                bne cmpsecwr

                ;skip tail #$DE #$AA #$EB some #$FFs ...

                ldy #$24
minus22         dey
                bpl minus22

                ;write sector data

unrlatch1=unrelocdsk+(*-reloc)
                lda $c0ed   ;prime drive
unrlatchin1=unrelocdsk+(*-reloc)
                lda $c0ee   ;required by Unidisk
                tya
                ldx #$56
unrlatchout=unrelocdsk+(*-reloc)
                sta $c0ef
unrread4=unrelocdsk+(*-reloc)
                ora $c0ec

                ;40 cycles

                ldy #4                 ;2 cycles
                cmp $ea                ;3 cycles
                cmp ($ea,x)            ;6 cycles
minus23         jsr writenib1          ;(29 cycles)

                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus23            ;3 cycles if taken, 2 if not

                ;36 cycles
                                       ;+10 cycles
                ldy #(prolog_e-prolog) ;2 cycles
                cmp $ea                ;3 cycles
minus24         lda prolog-1, y        ;4 cycles
                jsr writenib3          ;(17 cycles)

                ;32 cycles if branch taken
                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus24            ;3 cycles if taken, 2 if not

                ;36 cycles on first pass
                                       ;+10 cycles
                tya                    ;2 cycles
                !byte $c5              ;(1 cycle), turns into cmp $ea and 3 cycles
minus25         nop                    ;2 cycles
                cmp $ea                ;3 cycles
                eor bit2tbl-1, x       ;4 cycles
                tay                    ;2 cycles
                lda xlattbl, y         ;4 cycles
unrlatch2=unrelocdsk+(*-reloc)
                sta $c0ed              ;4 cycles
unrread5=unrelocdsk+(*-reloc)
                lda $c0ec              ;4 cycles

                ;32 cycles if branch taken

                lda bit2tbl-1, x       ;4 cycles
                dex                    ;2 cycles
                bne minus25            ;3 cycles if taken, 2 if not

                ;32 cycles
                                       ;+8 cycles
                !byte $c5              ;(1 cycle), turns into cmp $ea and 3 cycles
minus26         nop                    ;2 cycles
                cmp $ea                ;3 cycles
                eor encbuf, x          ;4 cycles
                tay                    ;2 cycles
                lda xlattbl, y         ;4 cycles
unrlatch3=unrelocdsk+(*-reloc)
                sta $c0ed              ;4 cycles
unrread6=unrelocdsk+(*-reloc)
                lda $c0ec              ;4 cycles

                ;32 cycles if branch taken

                lda encbuf, x          ;4 cycles
                inx                    ;2 cycles
                bne minus26            ;3 cycles if taken, 2 if not

                ;32 cycles
                                       ;+8 cycles
                tax                    ;2 cycles
                lda xlattbl, x         ;4 cycles
                nop                    ;2 cycles
                nop                    ;2 cycles
                jsr writenib4          ;(14 cycles)

                ;32 cycles
                                       ;+6 cycles
                ldy #(epilog_e-epilog) ;2 cycles
                cmp $ea                ;3 cycles
minus27         lda epilog-1, y        ;4 cycles
                jsr writenib3          ;(17 cycles)

                ;32 cycles if branch taken
                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus27            ;3 cycles if branch taken, 2 if not

unrlatchin2=unrelocdsk+(*-reloc)
                lda $c0ee
unrread7=unrelocdsk+(*-reloc)
                lda $c0ec
                rts

writenib1       cmp ($ea,x)            ;6 cycles
writenib2       cmp ($ea,x)            ;6 cycles
writenib3       cmp $ea                ;3 cycles
writenib4
unrlatch4=unrelocdsk+(*-reloc)
                sta $c0ed              ;4 cycles
unrread8=unrelocdsk+(*-reloc)
                ora $c0ec              ;4 cycles
                rts                    ;6 cycles
prolog          !byte $ad, $aa, $d5
prolog_e
epilog          !byte $ff, $eb, $aa, $de
epilog_e
!align 255,0
  } ;enable_write
bit2tbl         = *
nibtbl          = bit2tbl+86
  !if enable_write=1 {
xlattbl         = nibtbl+106
dataend         = xlattbl+64
  } else { ;enable_write
dataend         = nibtbl+106
  } ;enable_write
;hack to error out when code is too large for current address
  !if reloc<$c000 {
    !if dataend>$c000 {
      !serious "code is too large"
    }
  }
} ;enable_floppy
} ;reloc

unrelochdd
!pseudopc reloc {
                ;read volume directory key block

hddopendir      lda #0
                sta adrlo
                asl reqcmd
                lsr reqcmd
unrhddblocklo=unrelochdd+(*-reloc)
                lda #2
unrhddblockhi=unrelochdd+(*-reloc)
                ldx #0
                jsr hddreaddirsec

!if enable_floppy=1 {
  !if (*-hddopendir) < (readdir-opendir) {
                ;essential padding to match offset with floppy version
    !fill (readdir-opendir)-(*-hddopendir), $ea
  }
} ;enable_floppy

                ;include volume directory header in count

hddreaddir
  !if might_exist=1 {
                ldx dirbuf+37
                inx
                stx entries
  }
  !if allow_subdir=1 {
                lda #0
  } ;allow_subdir
  !if might_exist=1 {
                sta status
                sta A2H
  } ;might_exist
hddfirstent     sta A2L
                lda #<(dirbuf+4)
                sta A1L
                lda #>(dirbuf+4)
                sta A1H
hddnextent      ldy #0
                lda (A1L), y
                and #$f0

  !if might_exist=1 {
                ;skip deleted entries without counting

                beq plus26
  } ;might_exist

  !if allow_subdir=1 {
                ;subdirectory entries are seedlings
                ;but we need to distinguish between them later

                cmp #$d0
                beq hddsavetype
  } ;allow_subdir

                ;watch for seedling and saplings only

                cmp #$30
                bcs plus25

                ;remember type

hddsavetype
  !if allow_subdir=1 {
                asl
                asl
  } else { ;allow_subdir
                cmp #$20
  } ;allow_subdir
                php

                ;match name lengths before attempting to match names

                lda (A1L), y
                and #$0f
                tax
                inx
                !byte $2c
minus28         lda (A1L), y
                cmp (namlo), y
                beq hddfoundname

                ;match failed, check if any directory entries remain

                plp
plus25
  !if might_exist=1 {
                inc A2H
                lda A2H
                cmp entries

                ;lock if entry not found

                bne plus26
                inc status
                rts
  }

                ;move to next directory in this block, if possible

plus26          clc
                lda A1L
                adc #$27
                sta A1L
                bcc plus27

                ;there can be only one page crossed, so we can increment instead of adc

                inc A1H
plus27          inc A2L
                lda A2L
                cmp #$0d
                bcc hddnextent

                ;read next directory block when we reach the end of this block

                lda dirbuf+2
                ldx dirbuf+3
                jsr hddreaddirsec
                bcc hddfirstent

hddfoundname    iny
                dex
                bne minus28

  !if enable_write=1 {
                ldy reqcmd
                dey
                php
                beq plus28

                ;round requested size up to nearest block
                ;and cache requested size if writing

                lda sizelo
                adc #$fe
                lda sizehi
                adc #1
                and #$fe
                tax

plus28
  } ;enable_write

                ;cache EOF (file size, loaded backwards)

                ldy #$16
                lda (A1L), y
                sta sizehi
                dey
                lda (A1L), y
                sta sizelo

  !if enable_write=1 {
                plp
                beq plus30

                ;round file size up to nearest block
                ;and check against requested size if writing

                ldy #2
                adc #$fe
                lda sizehi
                adc #1
                and #$fe
                beq plus29
                tay
                lda #0
plus29          sta sizelo
                sty sizehi

                ;set read size to min(length, requested size)

                cpx sizehi
                bcs plus30
                stx sizehi
plus30
  } ;enable_write

                ;cache AUX_TYPE (load offset for binary files)

  !if override_adr=0 {
    !if allow_subdir=1 {
                pla
                tax
    } else { ;allow_subdir
                plp
    } ;allow_subdir
                ldy #$1f
                lda (A1L), y
                pha
                iny
                lda (A1L), y
                pha
    !if allow_subdir=1 {
                txa
                pha
    } ;allow_subdir
  } ;override_adr

                ;cache KEY_POINTER (loaded backwards)

                ldy #$12
                lda (A1L), y
                tax
                sta dirbuf+256
                dey
                lda (A1L), y
                sta dirbuf
                ldy #0
                sty entries

                ;read index block in case of sapling

  !if allow_subdir=1 {
                plp
                bpl plus31
                php
                jsr hddreaddirsec
                plp
  } else { ;allow_subdir
    !if override_adr=1 {
                plp
    } ;override_adr
                bcc plus31
                jsr hddreaddirsec
  } ;allow_subdir

                ;restore load offset

plus31
  !if override_adr=1 {
                ldx ldrhi
                lda ldrlo
  } else { ;override_adr
                pla
                tax
                pla
  } ;override_adr

  !if allow_subdir=1 {
                ;check file type and fake size and load address for subdirectories

                bcc plus32
                ldy #2
                sty sizehi
    !if enable_write=1 {
                dey
                sty reqcmd
    } ;enable_write
                ldx #>dirbuf
                lda #<dirbuf
plus32
  } ;allow_subdir
                sta adrlo
                stx adrhi

  !if allow_aux=1 {
                ldx auxreq
                sta $c002, x
                sta $c004, x
  } ;allow_aux

                ;set read size to min(length, $200)

hddreadfile
  !if enable_write=1 {
                ldy reqcmd
                sty command
  } ;enable_write
                lda sizehi
                cmp #2
                bcs plus33
                pha
                lda #2
                sta sizehi
                lda adrhi
                pha
                lda adrlo
                pha
                lda #>dirbuf
                sta adrhi
                lda #0
                sta adrlo
plus33          php

                ;fetch data block and read it

                ldy entries
                inc entries
                lda dirbuf, y
                ldx dirbuf+256, y
                jsr hddseekread

                plp
                inc adrhi
                inc adrhi
                dec sizehi
                dec sizehi
                bne hddreadfile
                bcc plus34
                lda sizelo
                bne hddreadfile
  !if allow_aux=1 {
hddreaddone
                sta $c002
                sta $c004
  } ;allow_aux
                rts

plus34          pla
                sta A1L
                pla
                sta A1H
                dec adrhi
                dec adrhi
                pla
                tay
                beq plus35
                dey
minus29         lda (adrlo), y
                sta (A1L), y
                iny
                bne minus29
                inc A1H
                inc adrhi
plus35          lda sizelo
  !if allow_aux=1 {
                beq hddreaddone
  } else {
                beq plus36
  } ;allow_aux
minus30         lda (adrlo), y
                sta (A1L), y
                iny
                cpy sizelo
                bne minus30
  !if allow_aux=1 {
                beq hddreaddone
  } else {
plus36
                rts
  } ;allow_aux

hddreaddirsec   ldy #1
                sty command
                ldy #>dirbuf
                sty adrhi

hddseekread     sta bloklo
                stx blokhi

unrunit=unrelochdd+(*-reloc)
                lda #$d1
                sta unit

unrentry=unrelochdd+(*-reloc)
                jmp $d1d1
}
readbuff
!byte $D3,$C1,$CE,$A0,$C9,$CE,$C3,$AE
