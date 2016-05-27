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
                allow_subdir = 0        ;set to 1 to allow opening subdirectories to access files
                might_exist  = 0        ;set to 1 if file is not known to always exist already
                                        ;makes use of status to indicate success or failure
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
                status    = $f4         ;returns non-zero on error
}
                sizelo    = $f5         ;must set if writing
                sizehi    = $f6         ;must set if writing
                entries   = $f7         ;total number of entries
                reqcmd    = $f8         ;used if enable_write=1, 1=read, 2=write
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
                eor #4
                sta unrread1+1
                sta unrread2+1
                sta unrread3+1
  !if enable_write=1 {
                sta unrread4+1
                sta unrread5+1
                sta unrread6+1
                sta unrread7+1
                sta unrread8+1
                tax
                inx
                stx unrlatch1+1
                stx unrlatch2+1
                stx unrlatch3+1
                stx unrlatch4+1
                inx
                stx unrlatchin+1
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
                ldx #3
minus04         stx $3c
                txa
                asl
                bit $3c
                beq plus06
                ora $3c
                eor #$ff
                and #$7e
minus05         bcs plus06
                lsr
                bne minus05
                tya
                sta nibtbl, x
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
                ldy #0
-               lda unrelochdd, y
                sta reloc, y
                lda unrelochdd+$100, y
                sta reloc+$100, y
                iny
                bne -
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
unrblocklo=unrelocdsk+(*-reloc)
                lda #2
unrblockhi=unrelocdsk+(*-reloc)
                ldx #0
                jsr readdirsec

                ;include volume directory header in count

readdir         ldx dirbuf+37
                inx
                stx entries

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
minus06         lda (A1L), y
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
                bne minus06

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
                ;and construct single-entry index block in case of seedling

                ldy #$12
                lda (A1L), y
                tax
                sta dirbuf+256
                dey
                lda (A1L), y
                sta dirbuf
                ldy #0
                sty dirbuf+257
                sty dirbuf+1
                sty namlo

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
  !if override_adr=0 {
                pla
                tax
                pla
  } else { ;override_adr
                ldx ldrhi
                lda ldrlo
  }
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

                ;set read size to min(length, $200)

readfile        lda sizelo
                ldx sizehi
                cpx #2
                bcc plus18
                lda #0
                ldx #2
plus18          sta secsize1
                stx secsize2

                ;fetch data block and read it

                ldy namlo
                inc namlo
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
                bne plus19
                ldy secsize1
plus19          sty secsize
                dec secsize2
                jsr readadr

                ;if track does not match, then seek

                lda curtrk
                cmp phase
                beq checksec
                jsr seek

                ;[re-]read sector

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
cmpsecrd        jsr readadr
                cmp reqsec
                bne cmpsecrd

                ;read sector data

readdata        jsr readd5aa
                eor #$ad                ;zero A if match
;;                bne *                   ;lock if read failure
unrread1=unrelocdsk+(*-reloc)
minus07         ldx $c0ec
                bpl minus07
                eor nibtbl-$80, x
                sta bit2tbl-$aa, y
                iny
                bne minus07
unrread2=unrelocdsk+(*-reloc)
minus08         ldx $c0ec
                bpl minus08
                eor nibtbl-$80, x
                sta (adrlo), y          ;the real address
                iny
                cpy secsize
                bne minus08
                ldy #0
minus09         ldx #$a9
minus10         inx
                beq minus09
                lda (adrlo), y
                lsr bit2tbl-$aa, x
                rol
                lsr bit2tbl-$aa, x
                rol
                sta (adrlo), y
                iny
                cpy secsize
                bne minus10
readret         rts

  !if enable_write=1 {
encsec          iny
minus11         ldx #0
minus12         dey
                lda (adrlo), y
                lsr
                rol bit2tbl, x
                lsr
                rol bit2tbl, x
                sta encbuf, y
                lda bit2tbl, x
                and #$3f
                sta bit2tbl, x
                inx
                cpx #$56
                bcc minus12
                tya
                bne minus11

cmpsecwr        jsr readadr
                cmp reqsec
                bne cmpsecwr
                ldy #(epilog_e-epilog)
minus13         jsr readnib
                cmp epilog-1, y
                bne minus13
                dey
                bne minus13

                ;write sector data

unrlatch1=unrelocdsk+(*-reloc)
                lda $c0ed
                lda #$ff
unrlatchout=unrelocdsk+(*-reloc)
                sta $c0ef
unrread4=unrelocdsk+(*-reloc)
                ora $c0ec
                nop       ;2 cycles
                lsr phase ;7 cycles
                ldy #4
minus14         jsr writenib1
                dey
                bne minus14
                cmp $ea   ;3 cycles
                ldy #(prolog_e-prolog)
minus15         lda prolog-1, y
                jsr writenib3
                dey
                bne minus15
                tya
                ldy #$56
minus16         eor bit2tbl-1, y
                tax
                lda xlattbl, x
unrlatch2=unrelocdsk+(*-reloc)
                sta $c0ed
unrread5=unrelocdsk+(*-reloc)
                lda $c0ec
                asl phase ;7 cycles
                lda bit2tbl-1, y
                dey
                bne minus16
minus17         asl phase ;7 cycles
                eor encbuf, y
                tax
                lda xlattbl, x
unrlatch3=unrelocdsk+(*-reloc)
                sta $c0ed
unrread6=unrelocdsk+(*-reloc)
                lda $c0ec
                lda encbuf, y
                iny
                bne minus17
                tax
                lda xlattbl, x
                jsr writenib2
                cmp $ea   ;3 cycles
                ldy #(epilog_e-epilog)
minus18         lda epilog-1, y
                jsr writenib3
                dey
                bne minus18
unrlatchin=unrelocdsk+(*-reloc)
                lda $c0ee
unrread7=unrelocdsk+(*-reloc)
                lda $c0ec
                rts

writenib1       lsr phase ;7 cycles
                cmp $ea   ;3 cycles
                !byte $c9 ;2 cycles
writenib2       !byte $c9 ;2 cycles
writenib3       cmp $ea   ;3 cycles

unrlatch4=unrelocdsk+(*-reloc)
                sta $c0ed
unrread8=unrelocdsk+(*-reloc)
                ora $c0ec
                rts
prolog          !byte $ad, $aa, $d5
prolog_e
epilog          !byte $ff, $eb, $aa, $de
epilog_e
  } ;enable_write

                ;no tricks here, just the regular stuff

readadr
minus19         jsr readd5aa
                cmp #$96
                bne minus19
                ldy #3
minus20         sta curtrk
                jsr readnib
                rol
                sta tmpsec
                jsr readnib
                and tmpsec
                dey
                bne minus20
                rts

readd5aa
minus21         jsr readnib
minus22         cmp #$d5
                bne minus21
                jsr readnib
                cmp #$aa
                bne minus22
                tay                    ;we need Y=#$AA later

readnib
unrread3=unrelocdsk+(*-reloc)
minus23         lda $c0ec
                bpl minus23
seekret         rts

seek            sty step
                asl phase
                asl
copy_cur        tax
                sta tmptrk
                sec
                sbc phase
                beq seekret
                bcs plus20
                eor #$ff
                inx
                bcc plus21
plus20          sbc #1
                dex
plus21          cmp step
                bcc plus22
                lda step
plus22          cmp #8
                bcs plus23
                tay
                sec
plus23          txa
                pha
                ldx step1, y
                bne plus24
minus24         clc
                lda tmptrk
                ldx step2, y
plus24          stx tmpsec
                and #3
                rol
                tax
unrseek=unrelocdsk+(*-reloc)
                sta $c0e0, x
minus25         ldx #$13
minus26         dex
                bne minus26
                dec tmpsec
                bne minus25
                lsr
                bcs minus24
                pla
                inc step
                bne copy_cur

step1           !byte 1, $30, $28, $24, $20, $1e, $1d, $1c
step2           !byte $70, $2c, $26, $22, $1f, $1e, $1d, $1c

nibtbl          = *
bit2tbl         = nibtbl+128
  !if enable_write=1 {
xlattbl         = bit2tbl+86
dataend         = xlattbl+64
  } else { ;enable_write
dataend         = bit2tbl+86
  } ;enable_write
;hack to error out when code is too large for current address
  !if reloc<$c000 {
    !if dataend>$c000 {
      1=*
    }
  }
} ;enable_floppy
} ;reloc

unrelochdd
!pseudopc reloc {
                ;read volume directory key block

hddopendir      lda #0
                sta adrlo
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

hddreaddir      ldy dirbuf+37
                iny
                sty entries

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
minus27         lda (A1L), y
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
                bne minus27

  !if enable_write=1 {
                ldy reqcmd
                dey
                php
                beq plus30

                ;round requested size up to nearest block
                ;and cache requested size if writing

                lda sizehi
                tax
                lsr
                bcc plus28
                inx
plus28          cpx #2
                bcc plus29
                lda sizelo
                beq plus30
plus29          ldx #2
plus30
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
                beq plus34

                ;round file size up to nearest block
                ;and check against requested size if writing

                tay
                lsr
                bcc plus31
                iny
plus31          cpy #2
                bcc plus32
                lda sizelo
                beq plus33
plus32          lda #0
                sta sizelo
                ldy #2
plus33          sty sizehi

                ;set read size to min(length, requested size)

                cpx sizehi
                bcs plus34
                stx sizehi
plus34
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
                ;and construct single-entry index block in case of seedling

                ldy #$12
                lda (A1L), y
                tax
                sta dirbuf+256
                dey
                lda (A1L), y
                sta dirbuf
                ldy #0
                sty dirbuf+257
                sty dirbuf+1
                sty namlo

                ;read index block in case of sapling

  !if allow_subdir=1 {
                plp
                bpl plus35
                php
                jsr hddreaddirsec
                plp
  } else { ;allow_subdir
    !if override_adr=1 {
                plp
    } ;override_adr
                bcc plus35
                jsr hddreaddirsec
  } ;allow_subdir

                ;restore load offset

plus35
  !if override_adr=0 {
                pla
                tax
                pla
  } else { ;override_adr
                ldx ldrhi
                lda ldrlo
  } ;override_adr

  !if allow_subdir=1 {
                ;check file type and fake size and load address for subdirectories

                bcc plus36
                ldy #2
                sty sizehi
    !if enable_write=1 {
                dey
                sty reqcmd
    } ;enable_write
                ldx #>dirbuf
                lda #<dirbuf
plus36
  } ;allow_subdir
                sta adrlo
                stx adrhi

                ;set read size to min(length, $200)

hddreadfile
  !if enable_write=1 {
                ldy reqcmd
                sty command
  } ;enable_write
                lda sizehi
                cmp #2
                bcs plus37
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
plus37          php

                ;fetch data block and read it

                ldy namlo
                inc namlo
                lda dirbuf, y
                ldx dirbuf+256, y
                jsr hddseekread

                plp
                inc adrhi
                inc adrhi
                dec sizehi
                dec sizehi
                bne hddreadfile
                bcc plus38
                lda sizelo
                bne hddreadfile
                rts

plus38          pla
                sta A1L
                pla
                sta A1H
                dec adrhi
                dec adrhi
                pla
                tay
                beq plus39
                dey
minus28         lda (adrlo), y
                sta (A1L), y
                iny
                bne minus28
                inc adrhi
                inc A1H
plus39
minus29         lda (adrlo), y
                sta (A1L), y
                iny
                cpy sizelo
                bne minus29
                rts

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
