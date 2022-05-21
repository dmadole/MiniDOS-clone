# minfo

minfo is an Elf/OS utility for kernel 0.4.0 or later that displays information about memory usage on the machine. There are some significant changes in build 3 that affect the display of memory, in particular the amount of memory is no longer obtained from f_freemem, but rather from the top of the heap. The heap blocks are now also displayed first, since we need to traverse the heap to know it's top.

Output might look as follows:

```HEAP:
Addr  Size  Flags        References
----  ----  -----------  ----------
F300  00D1  46 .N...PA.  (Disk) "Hydro"
F3D4  0029  01 .......F
F400  01D2  46 .N...PA.  (File) "Turbo"
F5D5  012B  01 .......F
F703  00FC  06 .....PA.  (Stack)

MEMORY:
Base  Heap  Last  Size  Prog  Free
----  ----  ----  ----  ----  ----
2000  F2FD  F7FF  F800  D2FE  0154

STACK:
Frst  Curr  Last  Size  Low   Free
----  ----  ----  ----  ----  ----
F703  F7FA  F7FE  00FC  00B6  00F7
```

In the HEAP section:
* Addr is the address of the block in the heap (this is the start of the data, not the header)
* Size is the amount of data space within the block (the number of bytes between the end of the block's header and the start of the next block's header)
* Flags are the flags field in the header that contains attributes of the block, shown in both hex and decoded form (N=Named, P=Permanent, A=Allocated, F=Free)
* References contains in parenthesis from which categories of kernel API hooks are there hooks pointing into this heap block; also, in quotes, any name that is assigned to the block.

In the MEMORY section:
* Base is the lowest address for Elf/OS programs to load at
* Heap is the address of the bottom of the heap (what is in k_heap)
* Last is the highest RAM address (the address of the "end of heap" byte)
* Prog is the amount of contiguous memory available for an Elf/OS program and it's static data (the difference between Heap and Base).
* Free is the sum of the sizes of all free blocks within the heap.

In the STACK section:
* Frst (First) is the lowest stack address available
* Curr (Current) is the current value of the stack pointer (R2)
* Last is the highest stack address available
* Size is the number of bytes from first to last
* Low is the lowest amount of free stack space since the last time minfo was run. This is tracked by marking the free bytes on the stack with a pattern and seeing how far down that pattern has been disturbed.
* Free is the number of stack bytes not in use (the difference between the current address and the first address)

