#!/bin/env python3
#
# Generate/read probabilities of starting state
# for given 8 bit output sequence. Each bit is
# for bits apart and retrieved after splitting
# even/odd sequence.
#
# Elliot Buller
# 2022
#

from Crypto1 import *
import argparse
import json

# Convert initial state to index
ilookup = [[0, 2, 4, 5, 6, 7, 8, 9, 10, 12, 19, 21, 23, 24, 25, 28],
           [1, 3, 11, 13, 14, 15, 16, 17, 18, 20, 22, 26, 27, 29, 30, 31]]

def XOR (key):
    return key[47] ^ key[42] ^ key[38] ^ key[37] ^ key[35] ^ key[33] ^ \
        key[32] ^ key[30] ^ key[28] ^ key[23] ^ key[22] ^ key[20] ^ \
        key[18] ^ key[12] ^ key[8] ^ key[6] ^ key[5] ^ key[4]

# Rewind state 45 cycles
def Rewind (key):
    state = int2binarr (key, 48)[::-1]
    for n in range (45):
        a = state[0]
        state = state[1:48] + [0]
        state[47] = XOR(state) ^ a
    return binarr2int (state[::-1])

if __name__ == '__main__':

    parser = argparse.ArgumentParser ()
    parser.add_argument ('--gen_cnt', type=int,
                         help='Generate json file containing index probabilities')
    parser.add_argument ('--gen_c', action='store_true',
                         help='Generate C header from json file')
    parser.add_argument ('--get_idx', type=str,
                         help='Get even/odd index for bitstream')
    parser.add_argument ('--get_random', action='store_true',
                         help='Get random valid key and indices')
    parser.add_argument ('--rewind', type=str,
                         help='Rewind key 45 cycles')
    args = parser.parse_args ()


    # Generate pickle file
    if args.gen_cnt:

        # Create array of counts based on random key/output pair
        cnt = [[0] * 32 for x in range (256)]

        # Execute given sample size
        for n in range (args.gen_cnt):
            
            # Use monte-carlo random num gen to create key
            cipher = Crypto1 (state=random.randint (1, 2**48))

            # Get 64 bit output
            out = cipher.Raw (64)

            # Extract bits corresponding to even NLF ops
            even = out[0::2]

            # Take every 4th bit from that
            bits = even[0::4]

            # Convert to 8 bit int
            idx = binarr2int (bits)

            # Get initial NLFC(input) as int
            val = binarr2int (cipher.Start ())

            # Store in array
            cnt[idx][val] += 1

        # Convert to list of probabilities
        # Index will be output bits
        # 16 list elements will contain the
        # float probabilites of the 16 starting
        # inputs to NLFC
        store = [[0] * 16 for x in range (256)]
        idx = 0
        for e in cnt:

            # Convert sparse array to compact array
            i = 0
            
            # Generate sum
            s = sum (e)

            # Normalize each value
            for v in e:
                if v:
                    store[idx][i] = v / s
                    i += 1

            # Increment output index
            idx += 1
            
        # Create output file
        with open ('crypto1_prob.json', 'w') as fp:

            # Write out json
            json.dump (store, fp)
            
    # Generate C header from pickle file
    elif args.gen_c:

        # Read json file
        with open ('crypto1_prob.json', 'r') as fp:
            store = json.load (fp)
            idx = 0
            for e in store:
                print ('{}: {}'.format (idx, e))
                idx += 1

    elif args.get_random:
        # Use monte-carlo random num gen to create key
        key = hex(random.randint (1, 2**48))
        args.get_idx = key

    elif args.rewind:
        # Rewind key
        key = int (args.rewind, 0)
        print ('Key={}'.format (hex(Rewind (key))))
        
    # Get even/odd index for key
    if args.get_idx:

        print ('Key={}'.format (args.get_idx))

        # Get bitstream
        cipher = Crypto1 (state=int(args.get_idx, 0))
        bs = cipher.Raw (64)

        # Create
        cipher = Crypto1 (state=int(args.get_idx, 0))

        # Get first output bit
        out0 = cipher.Raw (1)[0]

        # Get even idx
        idx = ilookup[out0].index (binarr2int(cipher.Start ()))
        print ('Even={}'.format (idx))

        # Move one bit forward and get state
        cipher = Crypto1 (state=binarr2int(cipher.State()))

        # Get first output bit
        out0 = cipher.Raw (1)[0]
        
        # Get even idx
        idx = ilookup[out0].index (binarr2int(cipher.Start ()))

        # Get odd idx
        print ('Odd={}'.format (idx))

        # Print bitstream
        print ('Bitstream={}'.format (hex (binarr2int (bs))))
