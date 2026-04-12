#!/usr/bin/env python3
"""Generate a COFF object file embedding ICU data directly.

Creates a .obj file in COFF format that can be linked directly by MSVC.
This is instant (no compilation or assembly needed) - it just writes
the binary format directly.
"""

import os
import struct
import sys
import time


def create_coff_obj(data, symbol_name, output_path, arch='x64'):
    """Create a minimal COFF .obj with one section containing data."""

    # Align data to 16 bytes
    aligned_data = data + b'\x00' * ((16 - len(data) % 16) % 16)

    symbol_name_bytes = symbol_name.encode('ascii')

    # COFF Header (20 bytes)
    if arch in ('ia32', 'x86', 'Win32'):
        machine = 0x14C   # IMAGE_FILE_MACHINE_I386
    else:
        machine = 0x8664  # IMAGE_FILE_MACHINE_AMD64
    num_sections = 1
    timestamp = int(time.time())
    # Symbol table offset: after header + section headers + raw data
    section_header_size = 40
    header_size = 20
    raw_data_offset = header_size + section_header_size
    raw_data_size = len(aligned_data)
    symtab_offset = raw_data_offset + raw_data_size
    num_symbols = 1
    optional_header_size = 0
    characteristics = 0  # No special flags

    coff_header = struct.pack('<HHIIIHH',
        machine, num_sections, timestamp,
        symtab_offset, num_symbols,
        optional_header_size, characteristics)

    # Section Header (40 bytes) - ".rdata" section for read-only data
    section_name = b'.rdata\x00\x00'  # 8 bytes, null-padded
    virtual_size = 0
    virtual_addr = 0
    size_of_raw_data = raw_data_size
    ptr_to_raw_data = raw_data_offset
    ptr_to_relocations = 0
    ptr_to_linenums = 0
    num_relocations = 0
    num_linenums = 0
    # IMAGE_SCN_CNT_INITIALIZED_DATA | IMAGE_SCN_ALIGN_16BYTES | IMAGE_SCN_MEM_READ
    section_chars = 0x40 | 0x00500000 | 0x40000000

    section_header = struct.pack('<8sIIIIIIHHI',
        section_name, virtual_size, virtual_addr,
        size_of_raw_data, ptr_to_raw_data,
        ptr_to_relocations, ptr_to_linenums,
        num_relocations, num_linenums, section_chars)

    # Symbol Table Entry (18 bytes)
    # For names <= 8 bytes, inline the name. For longer, use string table.
    if len(symbol_name_bytes) <= 8:
        sym_name = symbol_name_bytes.ljust(8, b'\x00')
        string_table = struct.pack('<I', 4)  # String table: just the size (4 bytes)
    else:
        # Name is in string table: first 4 bytes = 0, next 4 = offset into string table
        string_offset = 4  # Offset after the 4-byte size field
        sym_name = struct.pack('<II', 0, string_offset)
        # String table: size (4 bytes) + name + null
        strtab_content = symbol_name_bytes + b'\x00'
        string_table = struct.pack('<I', 4 + len(strtab_content)) + strtab_content

    sym_value = 0  # Offset within section
    sym_section = 1  # Section number (1-based)
    sym_type = 0  # No type
    sym_storage_class = 2  # IMAGE_SYM_CLASS_EXTERNAL (public)
    sym_aux = 0  # No aux symbols

    symbol_entry = sym_name + struct.pack('<IhHBB',
        sym_value, sym_section, sym_type, sym_storage_class, sym_aux)

    # Write the .obj file
    with open(output_path, 'wb') as f:
        f.write(coff_header)
        f.write(section_header)
        f.write(aligned_data)
        f.write(symbol_entry)
        f.write(string_table)

    print(f"Generated {output_path} ({os.path.getsize(output_path)} bytes, "
          f"data: {len(data)} bytes, symbol: {symbol_name})")


def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <input.dat> <output.obj> [arch]", file=sys.stderr)
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    arch = sys.argv[3] if len(sys.argv) > 3 else 'x64'

    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found", file=sys.stderr)
        sys.exit(1)

    with open(input_path, 'rb') as f:
        data = f.read()

    # Detect ICU version from the data file header.
    # The ICU data file contains entries like "icudt73l/..." where 73 is the
    # major version. The symbol name must match: icudtNN_dat.
    import re
    match = re.search(rb'icudt(\d+)', data)
    if match:
        icu_ver = match.group(1).decode('ascii')
    else:
        icu_ver = '73'  # fallback
    symbol_name = f'icudt{icu_ver}_dat'
    # On ia32, the symbol needs a leading underscore for cdecl linkage
    if arch in ('ia32', 'x86', 'Win32'):
        symbol_name = '_' + symbol_name
    create_coff_obj(data, symbol_name, output_path, arch=arch)


if __name__ == '__main__':
    main()
