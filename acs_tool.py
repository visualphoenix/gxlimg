#!/usr/bin/env python3
"""ACS (Auxiliary Code Set) tool for Amlogic BL2 firmware.

Extracts DDR/DDRT/PLL configuration data from an ACS source binary
and patches it into a BL2 destination binary. Used as a preprocessing
step before BL2 signing in the Amlogic boot image build pipeline.

Ported to Python 3 from the decompiled Python 2 original in
LibreELEC/amlogic-boot-fip.
"""

import sys
import shutil
import copy
import collections
from struct import unpack

ENTRY_POINT_OFFSET = 4
BL2_HEADER_OFFSET = 4096
ACS_TOOL_VERSION = 1

acs_v1 = collections.OrderedDict()
acs_v1['acs_magic'] = b'acs__'
acs_v1['chip_type'] = 1
acs_v1['version'] = 2
acs_v1['acs_set_length'] = 8
acs_v1['ddr_magic'] = b'ddrs_'
acs_v1['ddr_set_version'] = 1
acs_v1['ddr_set_length'] = 2
acs_v1['ddr_set_addr'] = 8
acs_v1['ddrt_magic'] = b'ddrt_'
acs_v1['ddrt_set_version'] = 1
acs_v1['ddrt_set_length'] = 2
acs_v1['ddrt_set_addr'] = 8
acs_v1['pll_magic'] = b'pll__'
acs_v1['pll_set_version'] = 1
acs_v1['pll_set_length'] = 2
acs_v1['pll_set_addr'] = 8

CHECK_EXCEPTS = ['ddr_set_addr', 'ddrt_set_addr', 'pll_set_addr']
CHECK_EXCEPTS_LENGTH = ['ddr_set_length', 'ddrt_set_length', 'pll_set_length']
KEY_VERSIONS = ['version', 'ddr_set_version', 'ddrt_set_version', 'pll_set_version']


class AcsTool:

    def __init__(self, file_des, file_des_tmp, file_src, debug):
        self.debug = int(debug)
        self.file_des = file_des
        self.file_src = file_src
        self.file_des_tmp = file_des_tmp
        self.acs_des = copy.deepcopy(acs_v1)
        self.acs_src = copy.deepcopy(acs_v1)
        self.acs_base = copy.deepcopy(acs_v1)

    def init_acs(self, acs_struct, file_name, bl2):
        with open(file_name, 'rb') as fh:
            fh.seek(ENTRY_POINT_OFFSET)
            acs_entry_point, = unpack('H', fh.read(2))
            acs_entry_point -= bl2 * BL2_HEADER_OFFSET
            seek_position = acs_entry_point
            self.log_print(file_name)
            for key in acs_struct.keys():
                fh.seek(seek_position)
                if isinstance(acs_struct[key], bytes):
                    seek_position += len(acs_struct[key])
                    acs_struct[key] = fh.read(len(acs_struct[key]))
                elif isinstance(acs_struct[key], int):
                    seek_position += acs_struct[key]
                    if acs_struct[key] == 1:
                        acs_struct[key], = unpack('B', fh.read(1))
                    else:
                        acs_struct[key], = unpack('H', fh.read(2))
                    if key in CHECK_EXCEPTS:
                        acs_struct[key] -= bl2 * BL2_HEADER_OFFSET
                self.log_print(f'{key} {acs_struct[key]}')

    def check_acs(self):
        err_counter = 0
        for key in self.acs_des.keys():
            if self.acs_des[key] != self.acs_src[key] and key not in CHECK_EXCEPTS:
                print(f"Warning! ACS {key} doesn't match!! "
                      f"{self.acs_des[key]}/{self.acs_src[key]}")

        for key in KEY_VERSIONS:
            if self.acs_des[key] > self.acs_src[key]:
                self.acs_des[key] = self.acs_src[key]
                print(f'Warning! ACS src {key} too old!')

        for key in self.acs_base.keys():
            if isinstance(self.acs_base[key], bytes):
                if self.acs_des[key] != self.acs_base[key]:
                    err_counter += 1
                    print(f'Error! ACS DES {key} error!! '
                          f'Value: {self.acs_des[key]}, Expect: {self.acs_base[key]}')
                if self.acs_src[key] != self.acs_base[key]:
                    err_counter += 1
                    print(f'Error! ACS SRC {key} error!! '
                          f'Value: {self.acs_src[key]}, Expect: {self.acs_base[key]}')

        if self.acs_des['version'] > ACS_TOOL_VERSION:
            print(f'Error! Please update acs tool! '
                  f'v{self.acs_des["version"]}>v{ACS_TOOL_VERSION}')
            err_counter += 1
        return err_counter

    def copy_data(self):
        with open(self.file_des_tmp, 'r+b') as f_des, \
             open(self.file_src, 'rb') as f_src:
            for key_addr, key_length in zip(CHECK_EXCEPTS, CHECK_EXCEPTS_LENGTH):
                f_des.seek(self.acs_des[key_addr])
                f_src.seek(self.acs_src[key_addr])
                f_des.write(f_src.read(self.acs_des[key_length]))

    def run(self):
        shutil.copyfile(self.file_des, self.file_des_tmp)
        self.init_acs(self.acs_des, self.file_des_tmp, 1)
        self.init_acs(self.acs_src, self.file_src, 0)
        if self.check_acs():
            print('ACS check failed! Compile Abort!')
            return -1
        self.copy_data()
        print('ACS tool process done.')
        return 0

    def log_print(self, log):
        if self.debug:
            print(log)


if __name__ == '__main__':
    if len(sys.argv) != 5 or sys.argv[1] in ('--help', '-help', '-h'):
        print('Usage: acs_tool.py <bl2.bin> <bl2_tmp.bin> <acs.bin> <debug(1/0)>')
        sys.exit(1)
    tool = AcsTool(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
    if tool.run():
        sys.exit(1)
