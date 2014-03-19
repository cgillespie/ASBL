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

#######################################
# FAT12 File System Header
#######################################
.global _start
_start:			jmp	main		# 3 bytes - jump to code
bs_OEMName:		.ascii	"ASBLv1.0"	# 8 bytes - Who created the FS
bpb_BytesPerSector:	.word	0x0200		# 512 bytes per sector
bpb_SectorsPerCluster:	.byte	0x01		# 1x512 < 32k - good
bpb_ReservedSectors:	.word	0x0001		# only this sector is resevered
bpb_NumberOfFATs:	.byte	0x02		# should be 2 for FAT12
bpb_RootEntriesCount:	.word	0x40		# 64x32/512=4 even number - good
bpb_TotalSectors16:	.word	0x0B40		# This drive is 2880 sectors big
bpb_Media:		.byte	0xF8		# 0xF8 for non-removable
bpb_FATsize16:		.word	0x0009		# Each FAT is 9 sectors
bpb_SectorsPerTrack:	.word	0x0012		# 18 sectors per track
bpb_NumberOfHeads:	.word	0x0002		# 2 heads
bpb_HiddenSectors:	.long	0x00000000	# No sectors are hidden
bpb_ToTalSectors32:	.long	0x00000000	# 0 - we used the 16 bit version
bs_DriveNumber:		.byte	0x80		# 0x80 - harddrive
bs_Reserved1:		.byte	0x00		# Reserved by Windows NT
bs_BootSignature:	.byte	0x29		# 0x29 - next 3 fields exist
bs_VolumeID:		.long	0x12345678	# Serial Number
bs_VolumeLabel:		.ascii	"ASBL VOLUME"	# 11 bytes - Volume Name
bs_FileSystemType:	.ascii	"FAT12   "	# 8 bytes - File System Type

#######################################
# Constants
#######################################
.equ	TEMP,	0x0500			# Address to load FAT data into
.equ	STAGE2,	0x7E00			# Address to load Stage2 into

#######################################
# Strings
#######################################
msgWelcome:	.ascii	"ABSL - A Simple Boot Loader"
		.byte	13, 10, 0
msgLoading:	.ascii	"Loading STAGE2.BIN "
		.byte	9, 0

msgFailure:	.ascii	"Error: System Halted"
		.byte	13, 10, 0

msgDone:	.ascii	"Done"
		.byte	13, 10, 0

stage2Name:	.ascii "STAGE2  BIN"

#######################################
# Variables
#######################################
bootDrive:	.byte	0x00		# The drive that this bootloader is on
cluster:	.word	0x0000		# The current cluster for calculations
dataStart:	.word	0x0000		# The sector on disk the data starts at

# Disk Address Packet
DAP:		.byte	0x10
		.byte	0x00
DAP.NumSectors:	.word	0x0000		# Number of sectors to read
DAP.Buffer1:	.word	0x0000		# Where to read into - low
DAP.Buffer2:	.word	0x0000		# Where to read into - high
DAP.Sector1:	.word	0x0000		# Where to read from - lowest
DAP.Sector2:	.word	0x0000		# Where to read from - low
DAP.Sector3:	.word	0x0000		# Where to read from - high
DAP.Sector4:	.word	0x0000		# Where to read from - highest

#######################################
# Methods
#######################################
#--------------------------------------
# Screen I/O
#--------------------------------------
screen.clear:
	movb	$0x00, %ah
	movb	$0x02, %al
	int	$0x10
	ret

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

#--------------------------------------
# Entry Point
#--------------------------------------
main:
	movb	%dl, (bootDrive)

	call	screen.clear
	mov	$msgWelcome, %si
	call	screen.print
	mov	$msgLoading, %si
	call	screen.print

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

	mov	$stage2Name, %si
disk.loopEntries:
	push	%cx
	movw	$0x000B, %cx

	push	%di
	rep	cmpsb
	pop	%di
	je	disk.loopEntries.done
	pop	%cx
	add	$0x0020, %di
	loop	disk.loopEntries
	jmp	failBoot
disk.loopEntries.done:

	movw	0x001A(%di), %dx	# 26-27th bytes refer to first cluster of file
	movw	%dx, (cluster)

disk.loadFAT:
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
	movw	$STAGE2, %bx
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

	push	(bootDrive)
	push	(bpb_BytesPerSector)
	push	(bpb_SectorsPerCluster)
	push	(bpb_ReservedSectors)
	push	(bpb_NumberOfFATs)
	push	(bpb_RootEntriesCount)
	push	(bpb_FATsize16)

	ljmp	$0x07E0, $0x0000

	# Control should never be returned to this code
	# after this point but just in case halt the cpu
	cli
	hlt

failBoot:
	mov	$msgFailure, %si
	call	screen.print
	cli
	hlt

#######################################
# Boot Signature
#######################################
.fill	510 - (. - _start), 1, 0
.word	0xAA55
