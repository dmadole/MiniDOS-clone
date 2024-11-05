
all: clone.bin

lbr: clone.lbr

clean:
	rm -f clone.lst
	rm -f clone.bin
	rm -f clone.lbr

clone.bin: clone.asm include/bios.inc include/kernel.inc
	asm02 -L -b clone.asm
	rm -f clone.build

clone.lbr: clone.bin
	rm -f clone.lbr
	lbradd clone.lbr clone.bin

