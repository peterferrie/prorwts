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
                allow_multi  = 0        ;set to 1 to allow multiple floppies
                check_checksum=0        ;set to 1 to enforce checksum verification for floppies
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
} ;might_exist
!if allow_aux=1 {
                auxreq    = $f4         ;set to 1 to read/write aux memory, else main memory is used
} ;allow_aux
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
                dirbuf    = reloc+$400
                encbuf    = dirbuf+$200
    } else { ;load_high
                reloc     = $bc00
                dirbuf    = reloc-$200
                encbuf    = dirbuf-$100
    } ;load_high
  } else { ;enable_write
    !if load_high=1 {
                reloc     = $d000
                dirbuf    = reloc+$300
    } else { ;load_high
                reloc     = $bd00
                dirbuf    = reloc-$200
    } ;load_high
  } ;enable_write
} else { ;enable_floppy
  !if load_high=1 {
                reloc     = $d000
                dirbuf    = reloc+$200
  } else { ;load_high
                reloc     = $be00
                dirbuf    = reloc-$200
  } ;load_high
} ;enable_floppy

init            jsr $fe93
                jsr $fe89
                lda $bf30
                sta x80_parms+1
                sta unrunit+1
                and #$70
!if enable_floppy=1 {
  !if enable_write=1 {
                sta unrslot1+1
                sta unrslot2+1
                sta unrslot3+1
                sta unrslot4+1
  } ;enable_write
} ;enable_floppy
                pha
!if enable_floppy=1 {
                ora #$80
                sta unrseek+1
                ora #8
  !if might_exist=1 {
                sta unrdrvoff1+1
  } ;might_exist
                sta unrdrvoff2+1
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
  !if check_checksum=1 {
                stx unrread4+1
  } ;check_checksum
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
plus02          cmp #<(readbuf+$1ff) ;4+($27*$0d)
                lda A1H
                sbc #>(readbuf+$1ff)
                bcc inextent

                ;read next directory block when we reach the end of this block

                lda readbuff+2
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
!if enable_floppy=1 {
                sta unrblocklo+1
                stx unrblockhi+1
} ;enable_floppy
                sta unrhddblocklo+1
                stx unrhddblockhi+1
plus03          sta x80_parms+4
                stx x80_parms+5
plus04          lda sizelo
                bne readblock

plus05          pla
                lsr
                lsr
                lsr
                tax
                lsr
                ora #$c0
                ldy $bf11, x
                cpy #$c8
                bcs set_slot
                tya
set_slot        sta slot+2
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
unrblocklo=unrelocdsk+(*-reloc)
                ldx #2
unrblockhi=unrelocdsk+(*-reloc)
                lda #0
                jsr readdirsel

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
firstent        lda #<(dirbuf+4)
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
                bne plus10
unrdrvoff1=unrelocdsk+(*-reloc)
                lda $c0e8
                inc status
                rts
  } ;might_exist

                ;move to next directory in this block, if possible

plus09          clc
plus10          lda A1L
                adc #$27
                sta A1L
                bcc plus11

                ;there can be only one page crossed, so we can increment instead of adc

                inc A1H
plus11          cmp #<(dirbuf+$1ff) ;4+($27*$0d)
                lda A1H
                sbc #>(dirbuf+$1ff)
                bcc nextent

                ;read next directory block when we reach the end of this block

                ldx dirbuf+2
                lda dirbuf+3
                jsr readdirsec
                beq firstent

foundname       iny
                dex
                bne minus07

  !if enable_write=1 {
                ldy reqcmd
                cpy #2
                bcc plus12

                ;round requested size up to nearest sector
                ;and cache requested size if writing

                ldx sizehi
                lda sizelo
                beq plus12
                inx
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
                bcc plus15

                ;round file size up to nearest sector
                ;and check against requested size if writing

                beq plus13
                lda sizelo
                beq plus14
                lda #0
plus13          sta sizelo
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

                ;cache KEY_POINTER

                ldy #$11
                lda (A1L), y
                tax
                sta dirbuf
                iny
                lda (A1L), y
                sta dirbuf+256
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
                jsr setaux
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
                ldx dirbuf, y
                lda dirbuf+256, y
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
                lda sizehi
                ora sizelo
                bne readfile

unrdrvoff2=unrelocdsk+(*-reloc)
readdone        lda $c0e8
  !if allow_aux=1 {
                ldx #0
setaux          sta $c004, x
                sta $c002, x
  } ;allow_aux
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
                beq plus23
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
plus23          php
                bne plus24
minus08         clc
                lda tmptrk
                ldx step2, y
plus24          stx tmpsec
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
                plp
                beq seekret
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
unrread1=unrelocdsk+(*-reloc)
minus15         lda $c0ec
                bpl minus15
                rts

readdirsel
  !if enable_write=1 {
                ldy #1
                sty command
                dey
  } else { ;enable_write
                ldy #0
  } ;enable_write
                sty adrlo
                sty secsize1

  !if allow_multi=1 {
                asl reqcmd
                bcc seldrive
                iny
seldrive        lsr reqcmd
unrdrvsel=unrelocdsk+(*-reloc)
                cmp $c0ea, y
  } ;allow_multi

readdirsec
unrdrvon=unrelocdsk+(*-reloc)
                ldy $c0e9
                ldy #2
                sty secsize2
                ldy #>dirbuf
                sty adrhi

                ;convert block number to track/sector

seekread        lsr
                txa
                ror
                lsr
                lsr
                sta phase
                txa
                and #7
                cmp #4
                and #3
                php
                asl
                plp
                rol
                sta reqsec

                ;set read size to min(first size, $100) and then read address

                ldy #0
                lda secsize2
                bne plus25
                ldy secsize1
plus25          sty secsize
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
                inc reqsec
                inc reqsec

                ;force sector mismatch

cmpsecrd        lda #$ff

cmpsec
  !if enable_write=1 {
                ldy command
                dey
                bne encsec
  } ;enable_write
cmpsec2         cmp reqsec
                beq readdata
                jsr readadr
                beq cmpsec2

                ;read sector data

readdata        jsr readd5aa
                eor #$ad                ;zero A if match
;;                bne *                   ;lock if read failure
unrread2=unrelocdsk+(*-reloc)
minus16         ldx $c0ec
                bpl minus16
                eor nibtbl-$96, x
                sta bit2tbl-$aa, y
                iny
                bne minus16
unrread3=unrelocdsk+(*-reloc)
minus17         ldx $c0ec
                bpl minus17
                eor nibtbl-$96, x
                sta (adrlo), y          ;the real address
                iny
  !if check_checksum=1 {
                bne check_end
unrread4=unrelocdsk+(*-reloc)
minus18         ldx $c0ec
                bpl minus18
                eor nibtbl-$96, x
                bne cmpsecrd
check_end
  } ;check_checksum
                cpy secsize
                bne minus17
                ldy #0
minus19         ldx #$a9
minus20         inx
                beq minus19
                lda (adrlo), y
                lsr bit2tbl-$aa, x
                rol
                lsr bit2tbl-$aa, x
                rol
                sta (adrlo), y
                iny
                cpy secsize
                bne minus20
readret         inc adrhi
                rts

  !if enable_write=1 {
encsec          iny
minus21         ldx #$aa
minus22         dey
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
                bne minus22
                tya
                bne minus21

cmpsecwr        jsr readadr
                cmp reqsec
                bne cmpsecwr

                ;skip tail #$DE #$AA #$EB some #$FFs ...

                ldy #$24
minus23         dey
                bpl minus23

                ;write sector data

unrslot1=unrelocdsk+(*-reloc)
                ldx #$d1
                lda $c08d, x   ;prime drive
                lda $c08e, x   ;required by Unidisk
                tya
                sta $c08f, x
                ora $c08c, x

                ;40 cycles

                ldy #4                 ;2 cycles
                cmp $ea                ;3 cycles
                cmp ($ea,x)            ;6 cycles
minus24         jsr writenib1          ;(29 cycles)

                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus24            ;3 cycles if taken, 2 if not

                ;36 cycles
                                       ;+10 cycles
                ldy #(prolog_e-prolog) ;2 cycles
                cmp $ea                ;3 cycles
minus25         lda prolog-1, y        ;4 cycles
                jsr writenib3          ;(17 cycles)

                ;32 cycles if branch taken
                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus25            ;3 cycles if taken, 2 if not

                ;36 cycles on first pass
                                       ;+10 cycles
                tya                    ;2 cycles
                ldy #$56               ;2 cycles
minus26         eor bit2tbl-1, y       ;5 cycles
                tax                    ;2 cycles
                lda xlattbl, x         ;4 cycles
unrslot2=unrelocdsk+(*-reloc)
                ldx #$d1               ;2 cycles
                sta $c08d, x           ;5 cycles
                lda $c08c, x           ;4 cycles

                ;32 cycles if branch taken

                lda bit2tbl-1, y       ;5 cycles
                dey                    ;2 cycles
                bne minus26            ;3 cycles if taken, 2 if not

                ;32 cycles
                                       ;+9 cycles
                clc                    ;2 cycles
minus27         eor encbuf, y          ;4 cycles
minus28         tax                    ;2 cycles
                lda xlattbl, x         ;4 cycles
unrslot3=unrelocdsk+(*-reloc)
                ldx #$d1               ;2 cycles
                sta $c08d, x           ;5 cycles
                lda $c08c, x           ;4 cycles
                bcs plus26            ;3 cycles if taken, 2 if not

                ;32 cycles if branch taken

                lda encbuf, y          ;4 cycles
                iny                    ;2 cycles
                bne minus27            ;3 cycles if taken, 2 if not

                ;32 cycles
                                       ;+10 cycles
                sec                    ;2 cycles
                bcs minus28            ;3 cycles

                ;32 cycles
                                       ;+3 cycles
plus26          ldy #(epilog_e-epilog) ;2 cycles
                cmp ($ea,x)            ;6 cycles
minus29         lda epilog-1, y        ;4 cycles
                jsr writenib3          ;(17 cycles)

                ;32 cycles if branch taken
                                       ;+6 cycles
                dey                    ;2 cycles
                bne minus29            ;3 cycles if branch taken, 2 if not

                lda $c08e, x
                lda $c08c, x
                inc adrhi
                rts

writenib1       cmp ($ea,x)            ;6 cycles
writenib2       cmp ($ea,x)            ;6 cycles
writenib3
unrslot4=unrelocdsk+(*-reloc)
                ldx #$d1               ;2 cycles
writenib4       sta $c08d, x           ;5 cycles
                ora $c08c, x           ;4 cycles
                rts                    ;6 cycles

prolog          !byte $ad, $aa, $d5
prolog_e
epilog          !byte $ff, $eb, $aa, $de
epilog_e
  } ;enable_write
bit2tbl         = (*+255) & -256
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
  } else {
    !if reloc<dirbuf {
      !if dataend>dirbuf {
        !serious "code is too large"
      }
    }
  }
} ;enable_floppy
} ;reloc

unrelochdd
!pseudopc reloc {
                ;read volume directory key block

hddopendir
unrhddblocklo=unrelochdd+(*-reloc)
                ldx #2
unrhddblockhi=unrelochdd+(*-reloc)
                lda #0
                jsr hddreaddirsel

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
hddfirstent     lda #<(dirbuf+4)
                sta A1L
                lda #>(dirbuf+4)
                sta A1H
hddnextent      ldy #0
                lda (A1L), y
                and #$f0

  !if might_exist=1 {
                ;skip deleted entries without counting

                beq plus28
  } ;might_exist

  !if allow_subdir=1 {
                ;subdirectory entries are seedlings
                ;but we need to distinguish between them later

                cmp #$d0
                beq hddsavetype
  } ;allow_subdir

                ;watch for seedling and saplings only

                cmp #$30
                bcs plus27

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
minus30         lda (A1L), y
                cmp (namlo), y
                beq hddfoundname

                ;match failed, check if any directory entries remain

                plp
plus27
  !if might_exist=1 {
                inc A2H
                lda A2H
                cmp entries

                ;lock if entry not found

                bne plus29
                inc status
                rts
  }

                ;move to next directory in this block, if possible

plus28          clc
plus29          lda A1L
                adc #$27
                sta A1L
                bcc plus30

                ;there can be only one page crossed, so we can increment instead of adc

                inc A1H
plus30          cmp #<(dirbuf+$1ff) ;4+($27*$0d)
                lda A1H
                sbc #>(dirbuf+$1ff)
                bcc hddnextent

                ;read next directory block when we reach the end of this block

                ldx dirbuf+2
                lda dirbuf+3
                jsr hddreaddirsec
                bcc hddfirstent

hddfoundname    iny
                dex
                bne minus30

  !if enable_write=1 {
                ldy reqcmd
                dey
                php
                beq plus31

                ;round requested size up to nearest block
                ;and cache requested size if writing

                lda sizelo
                jsr round
                tax

plus31
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
                beq plus33

                ;round file size up to nearest block
                ;and check against requested size if writing

                ldy #2
                jsr round
                beq plus32
                tay
                lda #0
plus32          sta sizelo
                sty sizehi

                ;set read size to min(length, requested size)

                cpx sizehi
                bcs plus33
                stx sizehi
plus33
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

                ;cache KEY_POINTER

                ldy #$11
                lda (A1L), y
                tax
                sta dirbuf
                iny
                lda (A1L), y
                sta dirbuf+256
                ldy #0
                sty entries

                ;read index block in case of sapling

  !if allow_subdir=1 {
                plp
                bpl plus34
                php
                jsr hddreaddirsec
                plp
  } else { ;allow_subdir
    !if override_adr=1 {
                plp
    } ;override_adr
                bcc plus34
                jsr hddreaddirsec
  } ;allow_subdir

                ;restore load offset

plus34
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

                bcc plus35
                ldy #2
                sty sizehi
    !if enable_write=1 {
                dey
                sty reqcmd
    } ;enable_write
                ldx #>dirbuf
                lda #<dirbuf
plus35
  } ;allow_subdir
                sta adrlo
                stx adrhi

  !if allow_aux=1 {
                ldx auxreq
                jsr hddsetaux
  } ;allow_aux

                ;set read size to min(length, $200)

hddreadfile
  !if enable_write=1 {
                ldy reqcmd
                sty command
  } ;enable_write
                lda sizehi
                cmp #2
                bcs plus36
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
plus36          php

                ;fetch data block and read it

                ldy entries
                inc entries
                ldx dirbuf, y
                lda dirbuf+256, y
                jsr hddseekread

                plp
                inc adrhi
                inc adrhi
                dec sizehi
                dec sizehi
                bne hddreadfile
                bcc plus37
                lda sizelo
                bne hddreadfile
  !if allow_aux=1 {
hddreaddone     ldx #0
hddsetaux       sta $c004, x
                sta $c002, x
  } ;allow_aux
                rts

plus37          pla
                sta A1L
                pla
                sta A1H
                dec adrhi
                dec adrhi
                pla
                tay
                beq plus38
                dey
minus31         lda (adrlo), y
                sta (A1L), y
                iny
                bne minus31
                inc A1H
                inc adrhi
plus38          ldx sizelo
  !if allow_aux=1 {
                beq hddsetaux
  } else {
                beq plus39
  } ;allow_aux
minus32         lda (adrlo), y
                sta (A1L), y
                iny
                cpy sizelo
                bne minus32
  !if allow_aux=1 {
                beq hddreaddone
  } else {
plus39
                rts
  } ;allow_aux

round           adc #$fe
                lda sizehi
                adc #1
                and #$fe
                rts

hddreaddirsel   ldy #0
                sty adrlo
                asl reqcmd
                lsr reqcmd

hddreaddirsec   ldy #1
                sty command
                ldy #>dirbuf
                sty adrhi

hddseekread     stx bloklo
                sta blokhi

unrunit=unrelochdd+(*-reloc)
                lda #$d1
                sta unit

unrentry=unrelochdd+(*-reloc)
                jmp $d1d1
}
readbuff
!byte $D3,$C1,$CE,$A0,$C9,$CE,$C3,$AE
