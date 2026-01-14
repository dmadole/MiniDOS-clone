
;  Copyright 2021, David S. Madole <david@madole.net>
;
;  This program is free software: you can redistribute it and/or modify
;  it under the terms of the GNU General Public License as published by
;  the Free Software Foundation, either version 3 of the License, or
;  (at your option) any later version.
;
;  This program is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License
;  along with this program.  If not, see <https://www.gnu.org/licenses/>.


          ; Include BIOS and kernal API entry points

            #include include/bios.inc
            #include include/kernel.inc


          ; Define non-published API elements

d_ideread:  equ   0447h
d_idewrite: equ   044ah


          ; Executable program header

            org   2000h - 6
            dw    start
            dw    end-start
            dw    start

start:      org   2000h
            br    main

          ; Build information

            db    1+80h              ; month
            db    5                  ; day
            dw    2026               ; year
            dw    6                  ; build

            db    'See github.com/dmadole/MiniDOS-clone for more info',0

          ; Main program

          ; Check that the filesystem type is 1 as that's all we know how
          ; do deal with. This is important since we are working at the
          ; disk block level and not going through the operating system.

main:       glo   r6                    ; yes, we are going to use r6
            stxd
            ghi   r6
            stxd

            ghi   ra
            phi   rf
            glo   ra
            plo   rf

            sep   scall                 ; get source drive
            dw    getdriv
            lbdf  dousage

            plo   r6

            sep   scall                 ; get target drive
            dw    getdriv
            lbdf  dousage

            phi   r6

skipspc:    lda   rf
            lbz   chkdisk
            sdi   ' '
            lbdf  skipspc

dousage:    sep   scall
            dw    o_inmsg
            db    "USAGE: clone //source //target",13,10,0

            lbr   return


chkdisk:    sep   scall                 ; send a greeting of sorts
            dw    o_inmsg
            db    "Checking disk type... ",0

            ldi   0                     ; pointer to the master sector
            plo   r7
            phi   r7
            plo   r8

            glo   r6                    ; specif source disk
            ori   0e0h
            phi   r8

            ldi   buffer.1              ; pointer to copy buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; get master sector to buffer
            dw    d_ideread
            lbdf  failed

            ldi   (buffer+104h).1       ; get pointer to filesystem type
            phi   rf
            ldi   (buffer+104h).0
            plo   rf

            ldn   rf                    ; compare to 1, proceed if so
            xri   1
            lbz   type1fs

            sep   scall                 ; else fail with error message
            dw    o_inmsg
            db    "Not a type 1 filesystem.",13,10
            db    "Cannot continue.",13,10,0

            lbr   return


          ; Confirm with user it's ok to proceed as this will destroy any
          ; data on the target disk.


type1fs:    sep   scall                 ; send warning
            dw    o_inmsg
            db    "Type 1 filesystem.",13,10
            db    "PROCEEDING WILL OVERWRITE THE CONTENTS OF DISK ",0

            ldi   string.1
            phi   rf
            ldi   string.0
            plo   rf

            ldi   0
            phi   rd
            ghi   r6
            plo   rd

            sep   scall
            dw    f_uintout

            ldi   '!'
            str   rf
            inc   rf

            ldi   0
            str   rf

            ldi   string.1
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall
            dw    o_msg

yousure:    sep   scall                 ; prompt for confirmation
            dw    o_inmsg
            db    13,10
            db    "Type YES to continue or ^C to abort: ",0

            ldi   string.1              ; buffer for input string
            phi   rf
            ldi   string.0
            plo   rf

            ldi   3.1                   ; only accept up to 3 bytes
            phi   rc
            ldi   3.0
            plo   rc

            sep   scall                 ; get input, if control-c then abort
            dw    o_inputl
            lbnf  proceed

            sep   scall                 ; acknowledge control-c typed
            dw    o_inmsg
            db    "^C",13,10,0

            lbr   return                ; return

          ; Check the input string to make sure it's exactly "YES", if
          ; it's not then send the confirmation prompt again.

proceed:    ldi   string.1              ; pointer to buffer
            phi   rf
            ldi   string.0
            plo   rf

            lda   rf                    ; first character
            xri   'Y'
            lbnz  yousure

            lda   rf                    ; second character
            xri   'E'
            lbnz  yousure

            lda   rf                    ; last character
            xri   'S'
            lbnz  yousure

            lda   rf                    ; terminating zero
            lbnz  yousure

            sep   scall                 ; echo return from input
            dw    o_inmsg
            db    13,10,0



          ; Get the size of the source disk so we know how many allocation
          ; units we need to consider copying.

            ldi   (buffer+10bh).1       ; pointer to number of aus
            phi   rf
            ldi   (buffer+10bh).0
            plo   rf

            lda   rf                    ; get numger of aus
            phi   rb
            phi   rd
            lda   rf
            plo   rb
            plo   rd

            sep   scall                 ; start output info
            dw    o_inmsg
            db    "Source disk is ",0

            sep   scall                 ; output disk size
            dw    sizeout

            sep   scall
            dw    o_inmsg               ; let user know we are busy
            db    ", scanning... ",0


          ; Scan the AU allocation table in the source disk, counting how
          ; many are actually in use, and building a bitmap in RAM of those
          ; we need to copy. A bitmap of all AUs would have 256 MB divided
          ; by 4 KB is 64K entries... at 8 bits per byte, this is 8KB of
          ; memory, which is resonable on any Elf/OS system.

            ldi   0                     ; clear current au and used count
            plo   r9
            phi   r9
            plo   ra
            phi   ra

            ldi   bitmap.1              ; get pointer to bitmap
            phi   rc
            ldi   bitmap.0
            plo   rc

scnloop:    glo   ra                    ; load a sector every 256 aus
            lbnz  gotsect

            ghi   ra                    ; au table starts at sector 17
            adi   17                    ;  and each sector is 256 entries,
            plo   r7                    ;  so add 17 to the msb of au to
            ldi   0                     ;  get sector number
            plo   r8
            adci  0
            phi   r7

            glo   r6                    ; specif source disk
            ori   0e0h
            phi   r8

            ldi   buffer.1              ; buffer to sector buffer
            phi   rf
            ldi   buffer.0
            plo   rf

            sep   scall                 ; get one sector of au map
            dw    d_ideread
            lbdf  failed

            ldi   buffer.1              ; reset buffer to start
            phi   rf
            ldi   buffer.0
            plo   rf

          ; Loop through each 16-bit au entry in the sector and count and
          ; mark in bitmap those that are in use.

gotsect:    adi   0                     ; clear df flag in case not used

            lda   rf                    ; if msb is not zero, it's in use
            lbnz  isused

            ldn   rf                    ; if msb and lsb zero, not in use
            lbz   notuse

isused:     ghi   ra                    ; fefe is a reserved value and will
            xri   0feh                  ;  not actually be used
            lbnz  notfefe

            glo   ra                    ; skip if the au is fefe
            xri   0feh
            lbz   notuse

notfefe:    smi   0                     ; set df flag since in use

            inc   r9                    ; increment used au count

notuse:     ldn   rc                    ; shift bit into bitmap byte
            shrc
            str   rc

            inc   ra                    ; advance to next au

            glo   ra                    ; every 8 aus we have filled a byte
            ani   7
            lbnz  notbyte

            inc   rc                    ; advance to next bitmap byte

notbyte:    inc   rf                    ; move to next au entry

            dec   rb                    ; loop if not all aus checked
            glo   rb
            lbnz  scnloop
            ghi   rb
            lbnz  scnloop


          ; Align the last bitmap byte if it ran short of allocation units.

            lbr  chkbyte

alignit:    ldn   rc
            shr
            str   rc

            inc   ra

chkbyte:    glo   ra
            ani   7
            lbnz  alignit


          ; Output a message with amount of data in use that we will copy.

            ghi   r9
            phi   rd
            glo   r9
            plo   rd

            sep   scall                 ; output disk size
            dw    sizeout

            sep   scall                 ; finish prompt and display
            dw    o_inmsg
            db    " is in use.",13,10
            db    "Copying used space... ",0


          ; Now that we know what to copy, here is where we actually do it.
          ; Each AU is 8 sectors, so we always have to copy in that size
          ; chunk. This means we are copying more data than we need to since
          ; some amount of trailing bytes of final AUs are unused, but there
          ; is no way around that unless we scan all the directory entries
          ; to find the length of each file. Probably it's about a wash.

            ldi   0                     ; clear sector counter
            plo   r7
            phi   r7
            plo   r8

            ldi   bitmap.1              ; get pointer to au bitmap
            phi   rc
            ldi   bitmap.0
            plo   rc


          ; Read the first sector of the target disk just to make sure it's
          ; working and be sure it's initialized if needed.

            ghi   r6                    ; specif source disk
            ori   0e0h
            phi   r8

            ldi   buffer.1              ; get pointer to sector buffer
            phi   rf
            ldi   buffer.0
            plo   rf
            
            sep   scall                 ; read target disk
            dw    d_ideread
            lbdf  failed                ; this seems to be broken


          ; This is the main loop that will actually perform the data copy.

cpyloop:    ldn   rc                    ; if au is not used, skip copying
            shr
            lbdf  cloneau

            glo   r7                    ; advance to next au to skip
            adi   7
            plo   r7
            inc   r7

            lbr   iscarry               ; check if 16-bit overflowed


          ; This is a sector of an AU that needs to be copied, so read from
          ; the source and write to the target. This will be repeated for
          ; each of the eight sectors in this AU.

cloneau:
            glo   r6                    ; specif source disk
            ori   0e0h
            phi   r8

            ldi   buffer.1              ; get pointer to sector buffer
            phi   rf
            ldi   buffer.0
            plo   rf

inputau:    sep   scall                 ; read sector from source
            dw    d_ideread
            lbdf  failed

            inc   r7                    ; increment sector until au done
            glo   r7
            ani   7
            lbnz  inputau

            dec   r7                    ; set sector back to start of au
            glo   r7
            smi   7
            plo   r7

            ghi   r6                    ; specif source disk
            ori   0e0h
            phi   r8

            ldi   buffer.1              ; get pointer to sector buffer
            phi   rf
            ldi   buffer.0
            plo   rf

writeau:    sep   scall                 ; write sector to target
            dw    d_idewrite
            lbdf  failed

            inc   r7                    ; increment sector until au done
            glo   r7
            ani   7
            lbnz  writeau


          ; After each sector we increment the sector counter and then
          ; check for multiples of 8 (AUs) and 64 (bitmap bytes).

iscarry:    glo   r7                    ; overflowed if wrapped to zero
            lbnz  nocarry
            ghi   r7
            lbnz  nocarry

            inc   r8                    ; carry into r8 if so
            
          ; Each type we copy an AU, decrement the count of used AUs
          ; that we made during the scan phase. This can let us exit early
          ; without going through a lot of trailing zeroes in the bitmap.

nocarry:    ldn   rc                    ; shift to next bit in bitmap,
            shr                         ;  check if we just copied an au
            lbnf  empty

            dec   r9                    ; if so, decrement used au count

empty:      str   rc                    ; update bitmap entry either way

          ; Every 8 * 8 = 64 sectors we have processed an entire bitmap
          ; byte so advance to the next one.

            glo   r7                    ; if we have not processed 8 aus
            ani   63                    ;  loop back and continue
            lbnz  notnext

            inc   rc                    ; otherwise move to next bitmap byte

notnext:    glo   r9                    ; if we've not copied all in-use
            lbnz  cpyloop               ;  aus, then loop back and continue
            ghi   r9
            lbnz  cpyloop

          ; If all in-use AUs have been copied, then we are done. Declare
          ; success and exit.

            sep   scall                 ; copy is complete, we are done
            dw    o_inmsg
            db    "completed successfully.",13,10,0

return:     irx                         ; restore r6
            ldxa
            phi   r6
            ldx
            plo   r6

            sep   sret                  ; return


getdriv:    lda   rf
            lbz   geterr
            sdi   ' '
            lbdf  getdriv

            adi   '/'-' '
            lbnz  geterr

            lda   rf
            smi   '/'
            lbnz  geterr

            sep   scall
            dw    f_atoi
            lbdf  geterr

            glo   rd
            sep   sret

geterr:     smi   0
            sep   sret



         ;  If a disk error occurs along the way, output an error message
         ;  indicating where and abort the mission.

failed:     sep   scall                 ; output error message
            dw    o_inmsg
            db    "error on drive ",0

            ghi   r8                    ; drive number as digit
            ani   15
            adi   '0'

            sep   scall                 ; output drive number
            dw    o_type

            sep   scall                 ; preface for sector
            dw    o_inmsg
            db    " at sector ",0

            ldi   string.1              ; pointer to buffer for sector
            phi   rf
            ldi   string.0
            plo   rf

            glo   r8                    ; get bits 16-23 of sector
            plo   rd

            sep   scall                 ; convert two hex digits
            dw    f_hexout2

            glo   r7                    ; get bits 0-15 of sector
            plo   rd
            ghi   r7
            phi   rd

            sep   scall                 ; convert four hex digits
            dw    f_hexout4

            ldi   0                     ; zero terminate
            str   rf

            ldi   string.1              ; back to beginning of buffer
            phi   rf
            ldi   string.0
            plo   rf

skpzero:    lda   rf                    ; skip over leading zeroes
            smi   '0'
            lbz   skpzero

            adi   '0'                   ; but leave the last zero
            lbnz  notlast
            dec   rf

notlast:    dec   rf                    ; undo last auto-increment

            sep   scall                 ; output sector number
            dw    o_msg

            sep   scall                 ; rest of failure message
            dw    o_inmsg
            db    "h.",13,10
            db    "Copy failed.",13,10,0

            lbr   return                ; return


sizeout:    ghi   rd
            ani   %11000000
            lbnz  sizembs

            glo   rd
            shl
            plo   rd
            ghi   rd
            shlc
            phi   rd

            glo   rd
            shl
            plo   rd
            ghi   rd
            shlc
            phi   rd

            ldi   string.1              ; pointer to au space field
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert au count to decimal
            dw    f_uintout

            ldi   0                     ; zero terminate
            str   rf

            ldi   string.1              ; get pointer to au space message
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; display au stace message
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    ' KB',0

            sep   sret


sizembs:    glo   rd                    ; divide by 256 and round for mb
            adi   128
            ghi   rd
            adci  0
            plo   rd                    ; save 9-bit mb free in rb

            ldi   0
            shlc
            phi   rd

            ldi   string.1              ; pointer to mb size template
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; convert to decimal string
            dw    f_uintout

            ldi   0                     ; zero terminate string
            str   rf

            ldi   string.1              ; pointer to beginning of mb free
            phi   rf
            ldi   string.0
            plo   rf

            sep   scall                 ; output mb free space string
            dw    o_msg

            sep   scall
            dw    o_inmsg
            db    ' MB',0

            sep   sret

string:    ds      10                   ; work space for number conversions
buffer:    ds      4096                 ; buffer to hold each disk sector
bitmap:    ds      8192                 ; bitmap of aus that are in use

end:       ; That's all, folks!

