#!/usr/bin/env python3

"""This is a script.

There are many like it, but this one is mine."""

import argparse
import logging
import sys
import re

logger = logging.getLogger(__name__)
logging.basicConfig(format='%(levelname)s - %(message)s', level=logging.INFO)

    #80001000:	6568                	.2byte	0x6568

def main(args):
    """Main function"""
    lines = []
    # Build database of bytes to preload
    for line in args.fn_dis:
        if m := re.match(r'^\s+([0-9A-Fa-f]+):\t([0-9A-Fa-f]+)\s+[a-z\.]', line):
            addr,val = m.groups()
            addr = int(addr,16)
            while len(val) > 0:
                lines.append(f"{hex(addr)} {val[-2:]}")
                val = val[:-2]
                addr += 1
    args.fn_out.write('\n'.join(lines) + '\n')

if __name__=='__main__':
    argparser = argparse.ArgumentParser(description='Convert .dis file to preload file')
    argparser.add_argument('fn_dis', type=argparse.FileType('r'), help='Disassembly file to parse')
    argparser.add_argument('fn_out', type=argparse.FileType('w'), default=sys.stdout, nargs='?', help='Output file (default: stdout)')
    argparse_args = argparser.parse_args()
    main(argparse_args)
