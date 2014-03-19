ASBL
====
A Simple Boot Loader

---

**ASBL** is a minimalistic boot loader for hobby OS development.
It can load and launch a basic 32 bit binary kernel from a FAT12 file system.

###Compiling
---
####Requirements
 - **binutils** - the assembler and linker
 - **make** - automate the build
 - **mkfs.msdos** - filesystem creation utility

Making ASBL is as simple as typing `make` into the terminal.
```bash
cd ASBL
make
```
This should produce the following files in the bin directory.

 - STAGE1.BIN
 - STAGE2.BIN
 - KERNEL.BIN
 - floppy.img

###Using
---
 1. Mount floppy.img to the filesystem.
    ``` bash
losetup -f      # get the next loop device eg /dev/loop0
losetup /dev/loop0 bin/floppy.img
mount /dev/loop0 ~/mnt
umount ~/mnt    # Then when you are done unmount
losetup -d /dev/loop0
```

 2. Place a copy of `STAGE2.BIN` into the root directory.
 3. Call your kernel `KERNEL.BIN` and place a copy into the root directory.

    **Important!** Your kernel **must** be in plain binary format.
    This can be achieved by passing `--oformat binary` to the linker
    or by adding the line `OUTPUT_FORMAT("binary")` to the linker script.
    Alternatively a tool such as `objcopy` can be used to rip
    a plain binary out of an executable.

    Currently only small kernels can be successfully loaded and executed.
    The kernel should be well under 1MB in size to be reliably loaded.
