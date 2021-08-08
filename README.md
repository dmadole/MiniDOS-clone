# minfo

minfo is an Elf/OS utility for kernel 0.4.0 or later that displays information about memory usage on the machine. Output might look as follows:

```MEMORY:
Frst  Base  Heap  Last  Size  Free
----  ----  ----  ----  ----  ----
0000  2000  76FD  7FFF  8000  56FE

HEAP:
Addr  Size  Flags        References
----  ----  -----------  ----------
7700  00D1  46 .N...PA.  (Disk) "Hydro"
77D4  0029  01 .......F
7800  0205  46 .N...PA.  (File) "Turbo"
7A08  01F5  01 .......F
7C00  013F  46 .N...PA.  (Output,Input) "Nitro"
7D42  01BE  01 .......F
7F03  00FC  06 .....PA.  (Stack)

STACK:
Frst  Curr  Last  Size  Free  Low
----  ----  ----  ----  ----  ----
7F03  7FFA  7FFE  00FC  00F7  00C0
```

In the MEMORY section:
* Frst (First) is the lowest RAM address
* Base is the lowest address for Elf/OS programs to load at
* Heap is the address of the bottom of the heap (what is in k_heap)
* Last is the highest RAM address (what f_freemem reports)
* Free is the amount of contiguous memory available for an Elf/OS program and it's static data (the difference between Heap and Base). This does not include free blocks within the heap.

In the HEAP section:
* Addr is the address of the block in the heap (this is the start of the data, not the header)
* Size is the amount of data space within the block (the number of bytes between the end of the block's header and the start of the next block's header)
* Flags are the flags field in the header that contains attributes of the block, shown in both hex and decoded form (N=Named, P=Permanent, A=Allocated, F=Free)
* References contains in parenthesis from which categories of kernel API hooks are there hooks pointing into this heap block; also, in quotes, any name that is assigned to the block.

In the STACK section:
* Frst (First) is the lowest stack address available
* Curr (Current) is the current value of the stack pointer (R2)
* Last is the highest stack address available
* Size is the number of bytes from first to last
* Free is the number of stack bytes not in use (the difference between the current address and the first address)
* Low is the lowest amount of free stack space since the last time minfo was run. This is tracked by marking the free bytes on the stack with a pattern and seeing how far down that pattern has been disturbed.

