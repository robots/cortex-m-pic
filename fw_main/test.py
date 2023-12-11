
import sys
import struct

from elftools.elf.elffile import ELFFile
from elftools.elf.relocation import RelocationSection
from elftools.elf.sections import SymbolTableSection
from elftools.elf.relocation import RelocationSection, RelocationHandler
from elftools.elf.descriptions import describe_reloc_type
from elftools.elf.constants import SH_FLAGS

def get_symbols_in_elf(eld):
    syms = {}
    for section in elf.iter_sections():
        if not isinstance(section, SymbolTableSection):
            continue
        for symbol in section.iter_symbols():
            sdata = {}
            sdata["type"] = symbol['st_info']['type']
            sdata["bind"] = symbol['st_info']['bind']
            sdata["size"] = symbol['st_size']
            sdata["visibility"] = symbol['st_other']['visibility']
            sdata["section"] = symbol['st_shndx']
            try:
                sdata["section"] = int(sdata["section"])
            except:
                pass
            sdata["value"] = int(symbol['st_value'])
            if str(symbol.name) in syms:
                continue
            syms[str(symbol.name)] = sdata
    return syms

def get_relocations_in_elf(elf):
    relh = RelocationHandler(elf)
    rels = []

    skip_sections = ['.text']

    for section in elf.iter_sections():
        if section.name in skip_sections:
            # skip sections in list
            continue

        if section['sh_flags'] & SH_FLAGS.SHF_ALLOC == 0:
            # skip not loaded sections - debug etc
            continue

        relsec = relh.find_relocations_for_section(section)

        if relsec is None:
            # skip section that have no relocation data
            continue

        symtable = elf.get_section(relsec['sh_link'])
        for rel in relsec.iter_relocations():
            if rel['r_info_sym'] == 0:
                continue
            rdata = {}
            rdata["offset"] = int(rel['r_offset'])
            rdata["info"] = rel['r_info']
            rdata["type"] = describe_reloc_type(rel['r_info_type'], elf)
            symbol = symtable.get_symbol(rel['r_info_sym'])
            if symbol['st_name'] == 0:
                symsec = elf.get_section(symbol['st_shndx'])
                rdata["name"] = str(symsec.name)
            else:
                rdata["name"] = str(symbol.name)
            rdata["value"] = symbol["st_value"]
            rels.append(rdata)
    return rels

with open(sys.argv[1], "rb") as f:
    elf = ELFFile(f)

    syms = get_symbols_in_elf(elf)
    rels = get_relocations_in_elf(elf)

    ram_area = (0x20000000, 0x2fffffff)
    flash_area = (0x08000000, 0x081fffff) 

    relocations = []

    for r in rels:
        s, t, offset = r["name"], r["type"], r["offset"]

        try:
            value = syms[s]["value"]
        except:
            continue

        if value < flash_area[0] or flash_area[1] < value:
            continue

        if r['offset'] < ram_area[0] or ram_area[1] < r['offset']:
            continue

        if t == "R_ARM_THM_CALL": # PC-relative, safe to ignore
            #print("Ignoring relocation R_ARM_THM_CALL for symbol '%s' of type '%s'" % (s, syms[s]["type"]))
            continue
        elif t == "R_ARM_GOT_BREL":
            #print("Found local relocation for symbol '%s' (offset is %X, value is %x)" % (s, offset, value))
            #local_relocs.append((s, offset, value))
            #rlist.append(r)
            continue
        elif t == "R_ARM_ABS32":
            #data_relocs.append((s, offset, value))
            print("Found data relocation for symbol '%s' offset %X, valuie %x)" % (s, offset, value))
            relocations.append(offset)
        elif t != "R_ARM_ABS32":
            print("Unknown relocation type '%s' for symbol '%s'" % (t, s))
            continue

    out = b''
    out += struct.pack("<I", len(relocations))
    for r in relocations:
        out += struct.pack("<I", r)

    with open("output.bin", "wb") as fout:
        fout.write(out)
