#!/bin/env python3
#
# Recover crypto1 key using FPGA
#

import Flexsoc as flex
import atexit
import time

class FPGACrypto1:

    def __init__ (self, dev):
        self.flex = flex.Flexsoc (dev)
        atexit.register (self.cleanup)
        
    def cleanup (self):
        self.flex.Close ()

    def int2binarr (self, val, length):
        l = [int(x) for x in list(bin(val)[2:])]
        pad = [0] * (length - len(l))
        return (pad + l)

    def binarr2int (self, arr):
        return int (''.join([str(x) for x in arr]), 2)

    def XOR (self, key):
        return key[47] ^ key[42] ^ key[38] ^ key[37] ^ key[35] ^ key[33] ^ \
            key[32] ^ key[30] ^ key[28] ^ key[23] ^ key[22] ^ key[20] ^ \
            key[18] ^ key[12] ^ key[8] ^ key[6] ^ key[5] ^ key[4]
    
    # Rewind 45 cycles
    def Rewind (self, key):
        state = self.int2binarr (key, 48)[::-1]
        for n in range (45):
            a = state[0]
            state = state[1:48] + [0]
            state[47] = self.XOR(state) ^ a
        return self.binarr2int (state[::-1])
    
    # Recover key from bitstream
    def Recover (self, bitstream):

        # Write bitstream low
        self.flex.WriteWord (0x10, bitstream & 0xFFFFFFFF)

        # Write bitstream high
        self.flex.WriteHalf (0x14, (bitstream >> 32) & 0xFFFF)

        # Start recovery
        self.flex.WriteByte (0x18, 0)
        time.sleep (0.1)
        self.flex.WriteByte (0x18, 1)

        # Wait for completion
        stat = 0
        for n in range (100):
            stat = self.flex.ReadByte (0xE)
            #print ('stat={}'.format (hex (stat)))
            
            # Check done bit
            if stat & 1:
                break

            # Delay
            time.sleep (0.5)
            print ('.', flush=True, end='')
        print ('')
        if stat == 0:
            print ('Timeout')
            
        # Did we recover key?
        if stat & 2:
            key = self.flex.ReadHalf (0xC)
            key <<= 32
            key |= self.flex.ReadWord (4)

            # Rewind key and return
            key = self.Rewind (key)
            return key
        else:
            return None

from Crypto1 import *
import random

if __name__ == '__main__':

    crack = FPGACrypto1 ('/dev/ttyUSB1')

    # Try random valid bitstreams
    for n in range (12):

        # Create random key
        rkey = random.randint (1, 2**48)
        #rkey = 0xac6e61b52810
        
        # Generate output bitstream
        c = Crypto1 (state=rkey)
        bs = binarr2int (c.Raw (48))
        print ('bitstream={}'.format (hex (bs)))
        print ('Recovering key...')
        key = crack.Recover (bs)
        if key:
            print ('Found key: {}'.format (hex (key)))
            c = Crypto1 (state=key)
            bs2 = binarr2int (c.Raw (48))
            if bs == bs2:
                print ('Key check: OK')
        else:
            print ('Key not found')
    
