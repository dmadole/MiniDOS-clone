
clone.bin: clone.asm include/bios.inc include/kernel.inc
	asm02 -L -b clone.asm

clean:
	-rm -f clone.lst
	-rm -f clone.bin

