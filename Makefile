################################################################################
# ASBL - A Simple Boot Loader
#
# Copyright (C) 2014 Colin Gillespie
#
# This file is part of ASBL.
#
# ASBL is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASBL is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ASBL.  If not, see <http://www.gnu.org/licenses/>.
################################################################################

AS := as
LD := ld
OBJCOPY := objcopy
RM := rm -f

BINDIR := bin
SRCDIR := source

all: stage1 stage2 kernel floppy

stage1: $(BINDIR)/STAGE1.BIN
stage2: $(BINDIR)/STAGE2.BIN
kernel: $(BINDIR)/KERNEL.BIN
floppy: $(BINDIR)/floppy.img

$(BINDIR)/STAGE1.BIN: $(SRCDIR)/stage1.S
	@echo "Building stage 1"
	$(AS) -o $(BINDIR)/stage1.o $<
	$(LD) --oformat binary -Ttext 0x7C00 -o $@ $(BINDIR)/stage1.o
	@echo "Done"
	@echo ""

$(BINDIR)/STAGE2.BIN: $(SRCDIR)/stage2.S
	@echo "Building stage 2"
	$(AS) -o $(BINDIR)/stage2.o $<
	$(LD) --oformat binary --Ttext 0x7E00 -o $@ $(BINDIR)/stage2.o
	@echo "Done"
	@echo ""

$(BINDIR)/KERNEL.BIN: $(SRCDIR)/kernel.S $(SRCDIR)/kernel_link.ld
	@echo "Building test kernel"
	$(AS) -o $(BINDIR)/kmain.o $(SRCDIR)/kernel.S
	$(LD) -T $(SRCDIR)/kernel_link.ld -o $@ $(BINDIR)/kmain.o
	@echo "Done"
	@echo ""

$(BINDIR)/floppy.img: $(BINDIR)/STAGE1.BIN
	@echo "Building floppy image"
	@dd if=/dev/zero of=$@ bs=512 count=2880
	@mkfs.msdos -F 12 $@
	@dd if=$< of=$@ bs=512 conv=notrunc
	@echo "Done"
	@echo ""

clean:
	@$(RM) $(BINDIR)/*

.PHONY: all clean stage1 stage2 kernel floppy
