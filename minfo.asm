
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

           include bios.inc
           include kernel.inc


           ; Define non-published API elements

d_ideread  equ     0447h
d_idewrite equ     044ah


           ; Executable program header

           org     2000h - 6
           dw      start
           dw      end-start
           dw      start

start:     org     2000h
           br      main

           ; Build information

           db      8+80h              ; month
           db      7                  ; day
           dw      2021               ; year
           dw      1                  ; build

           db      'See github.com/dmadole/Elfos-minfo for more info',0

           ; Main program

           ; Check minimum needed kernel version 0.4.0 in order to have
           ; heap manager available.

main:      ldi     high k_ver         ; pointer to installed kernel version
           phi     rd
           ldi     low k_ver
           plo     rd

           lda     rd                 ; if major is non-zero then good
           lbnz    memshow

           lda     rd                 ; if minor is 4 or more then good
           smi     4
           lbdf    memshow

           sep     scall              ; quit with error message
           dw      o_inmsg
           db      'ERROR: Needs kernel version 0.4.0 or higher',13,10,0
           sep     sret


           ; Output general memory info

memshow:   sep     scall
           dw      o_inmsg
           db      'MEMORY:',13,10
           db      'Frst  Base  Heap  Last  Size  Free',13,10
           db      '----  ----  ----  ----  ----  ----',13,10,0

           sep     scall
           dw      f_freemem

           glo     rf
           plo     r7
           ghi     rf
           phi     r7

           ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           ; First address, hardcoded for now

           ldi     '0'
           str     rf
           inc     rf
           str     rf
           inc     rf
           str     rf
           inc     rf
           str     rf
           inc     rf

           ldi     ' '
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Base address, hardcoded for now

           ldi     '2'
           str     rf
           inc     rf

           ldi     '0'
           str     rf
           inc     rf
           str     rf
           inc     rf
           str     rf
           inc     rf

           ldi     ' '
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Heap address from k_heap

           ldi     high k_heap
           phi     r8
           ldi     low k_heap
           plo     r8

           lda     r8
           phi     rd
           ldn     r8
           plo     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     ' '
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Last address from f_freemem

           ghi     r7
           phi     rd
           glo     r7
           plo     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     ' '
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Size based on f_freemem with fixed zero

           ghi     r7
           phi     rd
           glo     r7
           plo     rd

           inc     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     ' '
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Free is heap minus base of 2000

           dec     r8
           lda     r8
           smi     020h
           phi     rd
           ldn     r8
           plo     rd

           inc     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     13
           str     rf
           inc     rf

           ldi     10
           str     rf
           inc     rf

           ldi     0
           str     rf

           ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           sep     scall
           dw      o_msg

           ; Show heap

heapshow:  ldi     high stdret+1
           phi     rf
           ldi     low stdret+1
           plo     rf

           sex     rf

           glo     r5
           stxd
           ghi     r5
           stxd

           glo     r4
           stxd
           ghi     r4
           stxd

           glo     r2
           stxd
           ghi     r2
           stxd

           glo     r0
           stxd
           ghi     r0
           stxd

           sex     r2

           sep     scall
           dw      o_inmsg
           db      13,10
           db      'HEAP:',13,10
           db      'Addr  Size  Flags        References',13,10
           db      '----  ----  -----------  ----------',13,10,0

           ldi     high k_heap
           phi     rf
           ldi     low k_heap
           plo     rf

           lda     rf
           phi     r7
           ldn     rf
           plo     r7


           ; Walk through all the blocks in the heap

heaploop:  ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           lda     r7                  ; get flags byte
           plo     r9
           lbz     heapdone

           lda     r7                  ; get length, advance to address
           phi     r8
           lda     r7
           plo     r8


           ; Output address of block

           ghi     r7                  ; get address of block
           phi     rd
           glo     r7
           plo     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf
           

          ; Output size

           ghi     r8
           phi     rd
           glo     r8
           plo     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf


           ; Output flags in hex

           glo     r9
           plo     rd

           sep     scall
           dw      f_hexout2

           ldi     32                  ; follow with one space
           str     rf
           inc     rf


           ; Output flags in readable format

           ldi     high flagname
           phi     rd
           ldi     low flagname
           plo     rd

           glo     r9
           phi     r9

flagloop:  ghi     r9
           shlc
           phi     r9

           lda     rd
           lbz     flagdone

           lbdf    flagset
           ldi     '.'

flagset:   str     rf
           inc     rf
           lbr     flagloop

flagname:  db      '7N543PAF',0

flagdone:  ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Output category names of kernel hooks pointing into this block

           ldi     high hooklist
           phi     rd
           ldi     low hooklist
           plo     rd

           ldi     0                   ; how many we found
           plo     r9

           lda     rd                  ; prime the pump

hookloop:  phi     ra                  ; get next vector address
           lda     rd
           plo     ra

           inc     ra                  ; skip lbr opcode, get target
           lda     ra
           phi     rb
           lda     ra
           plo     rb

           glo     r7                  ; subtract start of block from target
           str     r2
           glo     rb
           sm
           plo     rb
           ghi     r7
           str     r2
           ghi     rb
           smb
           phi     rb

           lbnf    hooknext            ; if negative, hook points below block

           glo     rb                  ; subtract offset in block from length
           str     r2
           glo     r8
           sm
           ghi     rb
           str     r2
           ghi     r8
           smb

           lbnf    hooknext            ; if negative, hook points above block

hookfind:  lda     rd                  ; skip any more vectors in the entry
           lbz     hooksave
           inc     rd
           lbr     hookfind

hooksave:  ghi     r7
           str     rd
           inc     rd
           glo     r7
           str     rd
           inc     rd

           glo     r9
           inc     r9
           lbnz    hook2nd

           ldi     '('
           str     rf
           inc     rf

           br      hookname

hook2nd:   ldi     ','
           str     rf
           inc     rf

hookname:  lda     rd
           lbz     hooklast
           str     rf
           inc     rf
           lbr     hookname

hooknext:  lda     rd
           lbnz    hookloop

           inc     rd
           inc     rd

hookskip:  lda     rd                  ; skip the text label in list
           lbnz    hookskip

hooklast:  lda     rd                  ; keep going if not end
           lbnz    hookloop

           glo     r9
           lbz     getname

           ldi     ')'
           str     rf
           inc     rf

           ldi     ' '
           str     rf
           inc     rf

           
           ; Output any name on this block

getname:   dec     r7                  ; get flags
           dec     r7
           dec     r7
           lda     r7
           inc     r7
           inc     r7

           ani     40h                 ; is 'named' flag set?
           lbz     heapout

           glo     r7                  ; add start and length
           str     r2
           glo     r8
           add
           plo     r9
           ghi     r7
           str     r2
           ghi     r8
           adc
           phi     r9

           ldi     '"'
           str     rf
           inc     rf

skipzer:   dec     r9
           ldn     r9
           lbz     skipzer

findzer:   dec     r9
           ldn     r9
           lbnz    findzer

           inc     r9

catname:   lda     r9
           str     rf
           inc     rf
           bnz     catname

           dec     rf

           ldi     '"'
           str     rf
           inc     rf

           ldi     ' '
           str     rf
           inc     rf

           ; Output line of data

heapout:   ldi     13
           str     rf
           inc     rf

           ldi     10
           str     rf
           inc     rf

           ldi     0
           str     rf
           
           ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           sep     scall
           dw      o_msg


           ; Move to next heap block

           glo     r7                  ; pointer to next block lsb
           str     r2
           glo     r8
           add
           plo     r7

           ghi     r7                  ; pointer to next block msb
           str     r2
           ghi     r8
           adc
           phi     r7

           lbr     heaploop


heapdone:  sep     scall
           dw      o_inmsg
           db      13,10
           db      'STACK:',13,10
           db      'Frst  Curr  Last  Size  Free  Low',13,10
           db      '----  ----  ----  ----  ----  ----',13,10,0

           ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           ldi     high stackblk
           phi     r7
           ldi     low stackblk
           plo     r7

           ; Output first stact address

           lda     r7
           phi     r8
           phi     rd
           lda     r7
           plo     r8
           plo     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Output current stack pointer

           glo     r2
           plo     rd
           ghi     r2
           phi     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Output last address of stack

           dec     r8
           dec     r8

           lda     r8
           phi     r9
           lda     r8
           plo     r9

           glo     r8
           str     r2
           glo     r9
           add
           plo     rd
           ghi     r8
           str     r2
           ghi     r9
           add
           phi     rd
           
           dec     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Output size of stack

           glo     r9
           plo     rd
           ghi     r9
           phi     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf

           ; Output stack free space

           glo     r8                  ; get free space in stack
           str     r2
           glo     r2
           sm
           plo     rc
           plo     rd
           ghi     r8
           str     r2
           ghi     r2
           smb
           phi     rc
           phi     rd

           sep     scall               ; output in hex
           dw      f_hexout4

           ldi     32                  ; follow with two spaces
           str     rf
           inc     rf
           str     rf
           inc     rf


           ; Output low water mark

           ldi     255                 ; count of untouched space to -1
           plo     rd
           phi     rd

           glo     r8                  ; get pointer to start of stack
           plo     ra
           ghi     r8
           phi     ra

           sex     ra                  ; so we can test against m(ra)

lowread:   glo     rc                  ; have we checked all free space?
           lbnz    lowmore
           ghi     rc
           lbz     lowstop

lowmore:   glo     ra                  ; compare ra.0 to m(ra)
           xor

           inc     ra                  ; increment pointer and untouched
           dec     rc                  ;  space, decrement free space count
           inc     rd

           lbz     lowread             ; if ra.0 equals m(ra) keep checking

           dec     ra                  ; back up pointer and count
           inc     rc

lowmark:   glo     rc                  ; have we filled all free space?
           bnz     lowwrit
           ghi     rc
           bz      lowstop

lowwrit:   glo     ra                  ; fill free stack byte
           str     ra

           inc     ra                  ; inc pointer and dec free space
           dec     rc

           lbr     lowmark             ; go until all free space is filled

lowstop:   sex     r2                  ; put back to stack pointer

           glo     rd                  ; did at least three bytes match?
           smi     3
           ghi     rd
           smbi    0

           bdf     lowprnt             ; if yes, then print low water mark

           ldi     high lownone        ; no, so wasn't initialized
           phi     ra
           ldi     low lownone
           plo     ra

lowcopy:   lda     ra                  ; copy string into buffer
           bz      prstack
           str     rf
           inc     rf
           lbr     lowcopy
 
lownone:   db      '****',13,10,13,10
           db      '**** Will be displayed on next run',0

lowprnt:   sep     scall               ; output in hex
           dw      f_hexout4


           ; Output stack info

prstack:   ldi     13
           str     rf
           inc     rf

           ldi     10
           str     rf
           inc     rf

           ldi     0
           str     rf

           ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf

           sep     scall
           dw      o_msg

           sep     sret


           ; This is a table of kernel "vector" entry points that are 
           ; checked to see if they point to within a heap block. The list
           ; in each entry is variable length, with the end marked by a
           ; zero byte (since the msb a vector is never zero this is ok).
           ; Following that zero is a word which will be filled in at the
           ; time the heap is scanned with the last matching heap block
           ; for that list. Finally is a zero-terminate description for 
           ; the list which will be displayed in the heap output. The end
           ; of the entire list is marked with a zero byte.

hooklist:  dw      o_boot, o_cldboot, o_wrmboot
           db      0
           dw      0
           db      'BOOT', 0

           dw      o_open, o_read, o_write, o_seek, o_close
           db      0
           dw      0
           db      'File', 0

           dw      o_opendir, o_delete, o_rename, o_mkdir, o_chdir, o_rmdir
           db      0
           dw      0
           db      'DIR', 0

           dw      o_rdlump, o_wrlump
           db      0
           dw      0
           db      'LUMP', 0

           dw      o_exec, o_execbin
           db      0
           dw      0
           db      'EXEC', 0

           dw      o_type, o_msg, o_inmsg, o_setbd
           db      0
           dw      0
           db      'Output', 0

           dw      o_readkey, o_input, o_inputl, o_brktest
           db      0
           dw      0
           db      'Input', 0

           dw      d_ideread, d_idewrite
           db      0
           dw      0
           db      'Disk', 0

           dw      o_prtstat, o_print
           db      0
           dw      0
           db      'PRINT', 0

           dw      o_getdev, o_devctrl
           db      0
           dw      0
           db      'DEV', 0

           dw      o_gettod, o_settod
           db      0
           dw      0
           db      'CLOCK', 0

           dw      o_alloc, o_dealloc
           db      0
           dw      0
           db      'HEAP', 0

           dw      o_initcall, stdcall-1, stdret-1
           db      0
           dw      0
           db      'SCRT', 0

           dw      stack-1
           db      0
stackblk:  dw      0
           db      'Stack', 0

           dw      v_ivec-1
           db      0
           dw      0
           db      'INT', 0

           dw      dma-1
           db      0
           dw      0
           db      'DMA', 0

           db      0

dma:       dw      0
stack:     dw      0
stdcall:   dw      0
stdret:    dw      0

buffer:    ds      100

end:       ; That's all, folks!

