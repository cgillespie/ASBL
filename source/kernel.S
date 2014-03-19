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

#
# This basic kernel just prints a message onto the screen
#

.code32
.text

.global _start
_start:
	xor	%edx, %edx
	movl	$0xB8320, %edx

	mov	$msgTest, %esi
	call	screen.print

	cli
	hlt

msgTest:	.ascii	"The test kernel was loaded just fine"
		.byte	0

screen.print:
	lodsb
	or	%al, %al
	jz	screen.print.nullChar
	mov	%al, (%edx)
	add	$0x2, %edx
	jmp	screen.print
screen.print.nullChar:
	ret
