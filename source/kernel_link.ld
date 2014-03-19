/* ASBL - A Simple Boot Loader
 *
 * Copyright (C) 2014 Colin Gillespie
 *
 * This file is part of ASBL.
 *
 * ASBL is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * ASBL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with ASBL.  If not, see <http://www.gnu.org/licenses/>.
 */

OUTPUT_FORMAT("binary")
ENTRY(_start)
SECTIONS {
	.text 0x100000 : {
		*(.text)
		*(.rodata)
		. = ALIGN(4096);
	}

	.data : {
		*(.data)
		. = ALIGN(4096);
	}

	.bss : {
		*(.bss)
		. = ALIGN(4096);
	}
}
