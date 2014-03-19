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

.code16
.text

.global _start
_start:
	jmp	main

#######################################
# File System info from stage 1
#######################################
bpb_BytesPerSector:	.word	0x0000
bpb_SectorsPerCluster:	.byte	0x00
bpb_ReservedSectors:	.word	0x0000
bpb_NumberOfFATs:	.byte	0x00
bpb_RootEntriesCount:	.word	0x00
bpb_FATsize16:		.word	0x0000

#######################################
# Constants
#######################################
.equ	STACK,	0x00090000
.equ	TEMP,	0x0500
.equ	KERNEL,	0x8200		# Stage 2 must fit between here and 0x7E00
.equ	FINAL,	0x100000	# The kernel will be ran at 1MB

#######################################
# Strings
#######################################
msgLoading:	.ascii	"Loading KERNEL.BIN "
		.byte	9, 0

msgFailure:	.ascii	"Error: System Halted"
		.byte	13, 10, 0

msgDone:	.ascii	"Done"
		.byte	13, 10, 0

kernelName:	.ascii "KERNEL  BIN"

#######################################
# Variables
#######################################
bootDrive:	.byte	0x00		# The drive that this bootloader is on
cluster:	.word	0x0000		# The current cluster for calculations
dataStart:	.word	0x0000		# The sector on disk the data starts at

#--------------------------------------
# Disk Address Packet
#--------------------------------------

DAP:		.byte	0x10
		.byte	0x00
DAP.NumSectors:	.word	0x0000		# Number of sectors to read
DAP.Buffer1:	.word	0x0000		# Where to read into - low
DAP.Buffer2:	.word	0x0000		# Where to read into - high
DAP.Sector1:	.word	0x0000		# Where to read from - lowest
DAP.Sector2:	.word	0x0000		# Where to read from - low
DAP.Sector3:	.word	0x0000		# Where to read from - high
DAP.Sector4:	.word	0x0000		# Where to read from - highest

#--------------------------------------
# The Global Descriptor Table (GDT)
#--------------------------------------
gdt:		# GDT address
gdt_null:	# null segment
	.long	0x00000000
	.long	0x00000000
gdt_code:	# code segment
	.word	0xFFFF
	.word	0x0000
	.byte	0x00
	.byte	0x9A		#10011010b
	.byte	0xCF		#11001111b
	.byte	0x00
gdt_data:	# data segment
	.word	0xFFFF
	.word	0x0000
	.byte	0x00
	.byte	0x92		#10010010b
	.byte	0xCF		#11001111b
	.byte	0x00
gdt_end:

gdtDescriptor:
	.word	gdt_end - gdt - 1
	.long	gdt

#######################################
# Methods
#######################################
#--------------------------------------
# Screen I/O
#--------------------------------------
screen.print:
	movb	$0x0E, %ah
screen.print.nextChar:
	lodsb
	or	%al, %al
	jz	screen.print.nullChar
	int	$0x10
	jmp	screen.print.nextChar
screen.print.nullChar:
	ret

#--------------------------------------
# Opens the A20 address line
#--------------------------------------
enableA20:
	cli

	call	a20wait
	movb	$0xAD, %al
	outb	%al, $0x64

	call	a20wait
	movb	$0xD0, %al
	outb	%al, $0x64

	call	a20wait2
	inb	$0x60, %al
	pushl	%eax

	call	a20wait
	movb	$0xD1, %al
	outb	%al, $0x64

	call	a20wait
	popl	%eax
	or	$0x02, %al
	outb	%al, $0x60

	call	a20wait
	movb	$0xAE, %al
	outb	%al, $0x64

	call	a20wait
	sti
	ret

a20wait:
	inb	$0x64, %al
	testb	$0x02, %al
	jnz	a20wait
	ret
a20wait2:
	inb	$0x64, %al
	testb	$0x01, %al
	jz	a20wait2
	ret

#--------------------------------------
# Disk I/O
#--------------------------------------
disk.clusterToLBA:
	sub	$0x0002, %ax
	xor	%cx, %cx
	movb	(bpb_SectorsPerCluster), %cl
	mul	%cx
	add	(dataStart), %ax
	ret

disk.readSectors:
	pusha
	mov	$0x05, %di
disk.readSectors.loop:
	movb	$0x42, %ah
	mov	$DAP, %si
	movb	(bootDrive), %dl
	int	$0x13
	jnc	disk.readSectors.done
	xor	%ax, %ax
	int	$0x13
	dec	%di
	jmp	failBoot
disk.readSectors.done:
	popa
	ret

disk.loadRoot:
	xor	%cx, %cx
	xor	%dx, %dx
	movw	$0x0020, %ax
	mulw	(bpb_RootEntriesCount)
	divw	(bpb_BytesPerSector)

	xchg	%cx, %ax

	movb	(bpb_NumberOfFATs), %al
	mulw	(bpb_FATsize16)
	add	(bpb_ReservedSectors), %ax
	movw	%ax, (dataStart)	# data is at the size of the FATs
	add	%cx, (dataStart)	# plus the size of the root directory

	movw	%cx, (DAP.NumSectors)
	movl	$TEMP, (DAP.Buffer1)
	movw	%ax, (DAP.Sector1)

	call	disk.readSectors

	movw	(bpb_RootEntriesCount), %cx
	movw	$TEMP, %di		# where we read the sectors to


disk.loopEntries:
	push	%cx
	movw	$0x000B, %cx
	mov	$kernelName, %si
	push	%di
	rep	cmpsb
	pop	%di
	je	disk.loadFAT
	pop	%cx
	add	$0x0020, %di
	loop	disk.loopEntries
	jmp	failBoot

disk.loadFAT:
	movw	0x001A(%di), %dx	# 26-27th bytes refer to first cluster of file
	movw	%dx, (cluster)
	xor	%ax, %ax
	movb	(bpb_NumberOfFATs), %al
	mulw	(bpb_FATsize16)
	movw	%ax, (DAP.NumSectors)

	movw	(bpb_ReservedSectors), %ax
	movw	%ax, (DAP.Sector1)

	movw	$TEMP, (DAP.Buffer1)
	call	disk.readSectors

	xor	%ax, %ax
	movw	%ax, %es
	movw	$KERNEL, %bx
	push	%bx

	movb	(bpb_SectorsPerCluster), %cl
	movb	%cl, (DAP.NumSectors)		# Read one cluster at a time

disk.loadImage:
	pop	%bx
	movw	%bx, (DAP.Buffer1)
	movw	(cluster), %ax
	call	disk.clusterToLBA
	movw	%ax, (DAP.Sector1)
	xor	%cx, %cx

	call	disk.readSectors
	# We need to increment our buffer pointer
	movw	(bpb_SectorsPerCluster), %ax
	mulw	(bpb_BytesPerSector)
	add	%ax, %bx
	push	%bx

	# Find the next cluster in the chain
	movw	(cluster), %ax
	movw	%ax, %cx
	movw	%ax, %dx
	shr	$0x0001, %dx	# divide by 2
	add	%dx, %cx	# add for 3/2
	movw	$TEMP, %bx
	add	%cx, %bx
	mov	(%bx), %dx
	test	$0x0001, %ax
	jnz	disk.loadImage.oddCluster
disk.loadImage.evenCluster:
	and	$0x0FFF, %dx	# take low 12 bits
	jmp	disk.loadImage.doneCluster
disk.loadImage.oddCluster:
	shr	$0x0004, %dx	# take high 12 bits
disk.loadImage.doneCluster:
	movw	%dx, (cluster)
	cmp	$0x0FF0, %dx
	jb	disk.loadImage
disk.loadImage.done:
	mov	$msgDone, %si
	call	screen.print

#--------------------------------------
# Prepare for Protected Mode
#--------------------------------------
	call	enableA20

	cli
	xor	%ax, %ax
	movw	%ax, %ds
	lgdt	(gdtDescriptor)		# load the GDT

	movl	%cr0, %eax
	or	$0x1, %eax		# enable 32bit mode
	movl	%eax, %cr0

	ljmp	$0x08, $moveKernel	# jump into 32bit code


failBoot:
	mov	$msgFailure, %si
	call	screen.print
	cli
	hlt

#--------------------------------------
# Entry Point
#--------------------------------------
main:
	pop	(bpb_FATsize16)
	pop	(bpb_RootEntriesCount)
	pop	(bpb_NumberOfFATs)
	pop	(bpb_ReservedSectors)
	pop	(bpb_SectorsPerCluster)
	pop	(bpb_BytesPerSector)
	pop	(bootDrive)

	mov	$msgLoading, %si
	call	screen.print

	jmp	disk.loadRoot

.code32
moveKernel:
	movw	$0x10, %ax
	movw	%ax, %ds
	movw	%ax, %es
	movw	%ax, %fs
	movw	%ax, %gs
	movw	%ax, %ss

	movl	$STACK, %esp
	movl	$KERNEL, %esi
	movl	$FINAL, %edi

	cld
	mov	$0x8000, %ecx	# Size of kernel
	rep	movsb

	ljmp	$0x08, $FINAL
