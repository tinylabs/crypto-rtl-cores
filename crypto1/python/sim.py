#!/bin/env python3
#
# Simulate FPGA architecture as PoC
#

import sys
import argparse
from multiprocessing import Process, Queue
import time

# Helpers
def binarr2int (arr):
    return int (''.join([str(x) for x in arr]), 2)

def int2binarr (val, length):
    l = [int(x) for x in list(bin(val)[2:])]
    pad = [0] * (length - len(l))
    return (pad + l)

class NLF:
    def __init__(self, name, fn, width):
        self.fn = fn
        self.width = width
        self.name = name
        
    def compute (self, val):
        if isinstance(val, list):
            val = binarr2int (val)
        _ = 1 if ((1 << val) & self.fn) != 0 else 0
        #print ('{}({})={}'.format (self.name, val, _))
        return _

    def enum (self, val):
        return [x for x in range (2**self.width) if self.compute(x) == val]

class Crypto1:
    def __init__ (self, key):
        self.state = key[::-1]
        self.nla = NLF('NLA', 0x9E98, 4)
        self.nlb = NLF('NLB', 0xB48E, 4)
        self.nlc = NLF('NLC', 0xEC57E80A, 5)

    def ComputeNLF (self):
        s = self.state
        layer1 = [self.nla.compute ([s[0],  s[2],  s[4],  s[6]]),
                  self.nlb.compute ([s[8],  s[10], s[12], s[14]]),
                  self.nla.compute ([s[16], s[18], s[20], s[22]]),
                  self.nla.compute ([s[24], s[26], s[28], s[30]]),
                  self.nlb.compute ([s[32], s[34], s[36], s[38]])]
        #return [self.nlc.compute (layer1), layer1]
        return self.nlc.compute (layer1)

    def RNLF (self):
        s = self.state
        return [
            binarr2int ([s[0],  s[2],  s[4],  s[6]]),
            binarr2int ([s[8],  s[10], s[12], s[14]]),
            binarr2int ([s[16], s[18], s[20], s[22]]),
            binarr2int ([s[24], s[26], s[28], s[30]]),
            binarr2int ([s[32], s[34], s[36], s[38]])]
    
    def XOR (self):
        key = self.state
        return key[47] ^ key[42] ^ key[38] ^ key[37] ^ key[35] ^ key[33] ^ \
            key[32] ^ key[30] ^ key[28] ^ key[23] ^ key[22] ^ key[20] ^ \
            key[18] ^ key[12] ^ key[8] ^ key[6] ^ key[5] ^ key[4]
        
    def OutState (self, cnt):
        _ = []
        for x in range (cnt):
            b = self.ComputeNLF ()
            #print ('NLF={} state={}'.format (b, self.state))
            _.append (b)
            # Shift new value
            self.state = [self.XOR ()] + self.state[0:47]
        return _

    def Output (self, cnt):
        _ = []
        for x in range (cnt):
            b = self.ComputeNLF ()
            _.append (b)
            self.state = [self.XOR ()] + self.state[0:47]
        return _

    def Reverse (self, cnt):
        for n in range (cnt):
            a = self.state[0]
            self.state = self.state[1:48] + [0]
            self.state[47] = self.XOR() ^ a
            
    def State (self):
        return self.state

    def Debug (self):
        print ('Internal state={}'.format(self.State()))
        key = self.state[0::2][:-4]
        print ('NLF(20)={} {}'.format (hex(binarr2int (key)), key))
        fx = self.RNLF ()
        print ('Fa={} Fb={} Fa={} Fa={} Fb={}'.format (fx[0], fx[1], fx[2], fx[3], fx[4]))
        b, fc = self.ComputeNLF ()
        print ('Output={} Fc={}\n'.format (b, fc))

class Enumerator:
    ''' 
    Enumerate 20 bit output given value 0 or one
    The iteration is composed of the following
    (although this is arbitrary):
    [4 Fc][3 Fb1][3 Fa1][3 Fa2][3 Fb2][3 Fa3]
    '''
    def __init__(self, index, bit_in):
        self.nla = NLF(0x9E98, 4)
        self.nlb = NLF(0xB48E, 4)
        self.nlc = NLF(0xEC57E80A, 5)
        self.Fa = [self.nla.enum(0), self.nla.enum(1)]
        self.Fb = [self.nlb.enum(0), self.nlb.enum(1)]
        self.Fc = [self.nlc.enum(0), self.nlc.enum(1)]
        self.bit_in = bit_in
        self.index = index

    def Test(self, val):
        s = int2binarr (val, 20)
        
        # Note: This is on split keys (odd/even) hence the indices
        layer1 = [self.nla.compute ([s[0],  s[1],  s[2],  s[3]]),
                  self.nlb.compute ([s[4],  s[5],  s[6],  s[7]]),
                  self.nla.compute ([s[8],  s[9],  s[10], s[11]]),
                  self.nla.compute ([s[12], s[13], s[14], s[15]]),
                  self.nlb.compute ([s[16], s[17], s[18], s[19]])]
        return self.nlc.compute (layer1)

    def __iter__(self):
        self.idx = 0
        return self
    
    def __next__(self):
        if self.idx >= 2**15:
            raise StopIteration
        
        # Get Fc
        Fc = int2binarr (self.Fc[self.bit_in][self.index], 5)
        k0 = self.Fa[Fc[0]][(self.idx >> 12) & 7]
        k1 = self.Fb[Fc[1]][(self.idx >> 9) & 7]
        k2 = self.Fa[Fc[2]][(self.idx >> 6) & 7]
        k3 = self.Fa[Fc[3]][(self.idx >> 3) & 7]
        k4 = self.Fb[Fc[4]][(self.idx >> 0) & 7]
        '''
        print (Fc)
        print (k0)
        print (k1)
        print (k2)
        print (k3)
        print (k4)
        '''
        val = (k0 << 16) | (k1 << 12) | (k2 << 8) | (k3 << 4) | k4
        self.idx += 1
        return val

class Pipeline (Process):
    ''' 
    Takes index and 4 bits of cipher output.
    Produces 16 replicated keystreams.
    '''
    def __init__ (self, index, bits=[]):
        Process.__init__(self)
        self.bits = bits
        self.nla = NLF(0x9E98, 4)
        self.nlb = NLF(0xB48E, 4)
        self.nlc = NLF(0xEC57E80A, 5)
        self.index = index
        
    def ComputeNLF (self, s):
        #s = int2binarr (val, 24)
        # Note: This is on split keys (odd/even) hence the indices
        layer1 = [self.nla.compute ([s[0],  s[1],  s[2],  s[3]]),
                  self.nlb.compute ([s[4],  s[5],  s[6],  s[7]]),
                  self.nla.compute ([s[8],  s[9],  s[10], s[11]]),
                  self.nla.compute ([s[12], s[13], s[14], s[15]]),
                  self.nlb.compute ([s[16], s[17], s[18], s[19]])]
        return self.nlc.compute (layer1)

    def ComputeShifted(self, b0, bits=[]):
            # Possibles
            stage1 = []
            stage2 = []
            stage3 = []
            stage4 = []

            ba = int2binarr (b0, 20)
            print ('Input={}'.format (ba))
            
            # Check bit0
            if self.ComputeNLF (ba[0:19] + [0]) == bits[0]:
                stage1.append (binarr2int (ba[0:20] + [0]))
            if self.ComputeNLF (ba[0:19] + [1]) == bits[0]:
                stage1.append (binarr2int (ba[0:20] + [1]))
            print ('stage1:')
            for x in stage1:
                print ('\t{}'.format (hex(x)))
            
            # Check bit1
            for b1 in stage1:
                ba = int2binarr (b1, 21)
                if self.ComputeNLF (ba[0:19] + [0])  == bits[1]:
                    stage2.append (binarr2int (ba[0:21] + [0]))
                if self.ComputeNLF (ba[0:19] + [1]) == bits[1]:
                    stage2.append (binarr2int (ba[0:21] + [1]))
            print ('stage2:')
            for x in stage2:
                print ('\t{}'.format (hex(x)))
            
            # Check bit2
            for b2 in stage2:
                ba = int2binarr (b2, 22)
                if self.ComputeNLF (ba[0:19] + [0])  == bits[1]:
                    stage3.append (binarr2int (ba[0:22] + [0]))
                if self.ComputeNLF (ba[0:19] + [1]) == bits[1]:
                    stage3.append (binarr2int (ba[0:22] + [1]))
            print ('stage3:')
            for x in stage3:
                print ('\t{}'.format (hex(x)))

            # Check bit3
            for b3 in stage3:
                ba = int2binarr (b3, 23)
                if self.ComputeNLF (ba[0:19] + [0])  == bits[1]:
                    stage4.append (binarr2int (ba[0:23] + [0]))
                if self.ComputeNLF (ba[0:19] + [1]) == bits[1]:
                    stage4.append (binarr2int (ba[0:23] + [1]))
            print ('stage4:')
            for x in stage4:
                print ('\t{}'.format (hex(x)))

            # Debug only
            #sys.exit (0)
            
            # Return results
            # Stage4 list now contains potentials (up to 8) with enough bits (24) to
            # combine with opposite bits and test using XOR feedback.
            return stage4
        
    def run (self):
        # Create enumerator to match bit 0
        enum = Enumerator (self.index, self.bits[0])
        for b0 in enum:

            print ('Enum: {}'.format(hex (b0)))

            # Pad b0 4 bits
            #b0 <<= 4
            
            # Cycle through and compute shifted
            ret = self.ComputeShifted (b0, self.bits[1:5])
            if len (ret) > 0:
                yield ret

class EvenPipeline (Pipeline):
    def __init__ (self, index, bits=[], q=[]):
        super (EvenPipeline, self).__init__ (index, bits)
        self.q = q

    def run (self):

        cnt = 0
        for klist in super (EvenPipeline, self).run ():
            # Send results to each queue
            for k in klist:
                for qi in self.q:
                    qi.put (k)
                print ('=> Passed: {}'.format(hex (k)))
                #self.q[0].put (k)
                #while not self.q[0].empty():
                #    time.sleep (0.1)
                cnt += 1
            #print ('\b\b\b\b\b{:.2f}%'.format ((cnt/2**15) * 100))
        print ('Even cnt={}'.format (cnt), flush=True)
                
        # Send none to terminate
        for qi in self.q:
            qi.put (None)
        #self.q[0].put (None)
        
class OddPipeline (Pipeline):
    def __init__ (self, index, sbits=[], vbits=[], q=None):
        super (OddPipeline, self).__init__ (index, sbits)
        self.q = q
        self.vbits = vbits
        
    def CheckXOR (self, key):
        return key[47] ^ key[42] ^ key[38] ^ key[37] ^ key[35] ^ key[33] ^ \
            key[32] ^ key[30] ^ key[28] ^ key[23] ^ key[22] ^ key[20] ^ \
            key[18] ^ key[12] ^ key[8] ^ key[6] ^ key[5] ^ key[4] ^ key[0] == 0

    def run (self):
        # Get next element from even queue
        while True:
            even = self.q.get()
            if even == None:
                print ('Odd done')
                return
            even = int2binarr (even, 24)
            
            # Rotate even right by one
            even = [even[23]] + even[0:23]
            
            # Run search space of 32768 for each element
            cnt = 0
            xor_passed = 0
            for klist in super (OddPipeline, self).run ():
                for k in klist:

                    #print ('Odd={}'.format (hex (k)))
                    # Convert to bin array
                    odd = int2binarr (k, 24)

                    # Merge keys
                    key = [item for sublist in zip(even, odd) for item in sublist]

                    # Check XOR
                    if self.CheckXOR (key):
                        xor_passed += 1
                    else:
                        continue
                    
                    # Generate output with Crypto1 to compare
                    # Skip first 10 bits
                    cipher = Crypto1 (key[::-1])
                    out = cipher.Output (len (self.vbits))
                    if out == self.vbits:
                        cipher.Reverse (len(self.vbits) + 10)
                        key = cipher.State ()[::-1]
                        print ('Found key={}'.format (hex (binarr2int (key))))
                        sys.exit (0)

                    cnt += 1
            print ('Odd cnt={} XOR passed={}'.format (cnt, xor_passed), flush=True)

class Crypto1Attack:
    '''
    Attack crypto1 cipher using pipelined approach
    '''
    def __init__(self, bitstream):
        search = bitstream[0:10]
        self.verify = bitstream[10:]
        self.even = search[0::2]
        self.odd = search[1::2]
        
    def Attack(self):

        epipe = []
        opipe = []
        q = [Queue() for x in range (256)]

        '''
        # Setup 16 even bit pipelines
        for n in range (16):
            epipe.append (EvenPipeline (n, self.even, q[n*16:n*16+16]))
            
        # Setup 256 odd pipelines
        for n in range (256):
            opipe.append (OddPipeline (n % 16, self.odd, self.verify, q[n]))

        # Run pipelines
        for n in range (256):
            opipe[n].start ()
        for n in range (16):
            epipe[n].start ()

        # Wait for threads to complete
        for n in range (16):
            epipe[n].join ()
        for n in range (256):
            opipe[n].join ()
        '''
        
        # Shortcut
        epipe.append (EvenPipeline (5, self.even, q[0:16]))
        #opipe.append (OddPipeline (0, self.odd, self.verify, q[0]))
        #opipe[0].start ()
        epipe[0].start ()
        epipe[0].join ()
        #opipe[0].join ()
        

if __name__ == '__main__':

    # Get bit string
    parser = argparse.ArgumentParser ()
    parser.add_argument ('--output', type=str, help='Output bits')
    parser.add_argument ('--key', type=str, help='key')
    parser.add_argument ('--len', type=int, help='bit length')
    parser.add_argument ('--truth', type=bool, help='Gen truth table')
    args = parser.parse_args ()

    # Generate truth table for 20 bits input for all 1
    # output. Use to feed espresso for minimized equation
    if args.truth:
        for n in range (16):
            e = Enumerator (n, 1)
            for x in e:
                b = int2binarr (x, 20)
                a = ''
                for y in b:
                    a += str (y)
                print ('{} 1'.format (a))
                
    # Check full half key enum
    elif args.output and args.len:

        # Convert
        bitstream = int2binarr (int (args.output, 0), args.len)
        
        # Reverse
        cr = Crypto1Attack (bitstream)
        cr.Attack ()

    else:

        for n in range (48, 20, -1):
            cipher = Crypto1 (int2binarr (0xee3de5499562, 48))
            cipher.Reverse (n)
            print ('{}: {}'.format(n, hex(binarr2int(cipher.State()[::-1]))))
        sys.exit (0)
        
        # Test data
        # key   =0x27568d75631f
        # output=0x5a7be10a7259
        nla = NLF('NLA', 0x9E98, 4)
        nlb = NLF('NLB', 0xB48E, 4)
        nlc = NLF('NLC', 0xEC57E80A, 5)
        
        print ('NLA(0)={}'.format(nla.enum (0)))
        print ('NLA(1)={}'.format(nla.enum (1)))
        print ('NLB(0)={}'.format(nlb.enum (0)))
        print ('NLB(1)={}'.format(nlb.enum (1)))
        print ('NLC(0)={}'.format(nlc.enum (0)))
        print ('NLC(1)={}'.format(nlc.enum (1)))
        print ('=========')

        # Compare to RTL output
        '''
        for x in Enumerator (5, 0):
            print ('0x{:05x}'.format(x))
        sys.exit (0);
        '''
        
        # Run enumerator tests
        '''
        print ("Enumerator test...", end='', flush=True)
        for n in range (8):
            en = Enumerator (n, 0)
            for x in en:
                assert (en.Test (x) == 0)
        for n in range (8):
            en = Enumerator (n, 1)
            for x in en:
                assert (en.Test (x) == 1)
        print ('OK')
        '''

        # Check first 10 states
        cipher = Crypto1 (int2binarr (0x27568d75631f, 48))
        for n in range (10):
            print ('state={}'.format (hex(binarr2int(cipher.State()[::-1]))))
            x = cipher.Output (1)
            print (x)
        
        # Check subkeys
        cipher = Crypto1 (int2binarr (0x27568d75631f, 48))
        cipher.Debug ()
        cipher.Output (1)
        cipher.Debug ()

        # Check that subkeys enumerate
        for x in Enumerator (5, 0):
            if x == 0xe9fc7:
                print ('Even subkey found')
                break
        for x in Enumerator (0, 1):
            if x == 0x6512c:
                print ('Odd subkey found')
                break
        
        # Check pipeline ops
        pipe = Pipeline (0, [0, 0, 0, 0])
        cipher = Crypto1 (int2binarr (0x27568d75631f, 48))
        #print ('Even search states')
        for n in range (5):
            state = cipher.State ()[0::2]
            out = cipher.Output (2)
            print ('{}: {} {}'.format (out[0][0], hex(binarr2int(state)), state))
            print ('NLFC({})={}'.format (out[0][1], out[0][0]))
            #print ('next={} or {}'.format (hex(state>>1), hex((state>>1)|0x80000)))
            assert (pipe.ComputeNLF (state[0:20]) == out[0][0])
        print ()
        cipher = Crypto1 (int2binarr (0x27568d75631f, 48))
        cipher.Output(1)
        #print ('Odd search states')
        for n in range (5):
            state = cipher.State ()[0::2]
            out = cipher.Output (2)
            print ('{}: {} {}'.format (out[0][0], hex(binarr2int(state)), state))
            print ('NLFC({})={}'.format (out[0][1], out[0][0]))
            #print ('next={} or {}'.format (hex(state>>1), hex((state>>1)|0x80000)))
            assert (pipe.ComputeNLF (state[0:20]) == out[0][0])
        print ('Pipeline ComputeNLF OK...')
        
        # Test search
        cipher = Crypto1 (int2binarr (0x27568d75631f, 48))

        # 10 search bits
        search = [x for x, y in cipher.Output (10)]
        print ('Internal state after search: {}'.format (hex(binarr2int(cipher.State()))))
        print ('Internal state after search: {}'.format (cipher.State()))
        print ('Even: {}'.format (cipher.State()[0::2]))
        print ('Odd: {}'.format (cipher.State()[1::2]))
        
        # 40 verify bits
        verify = cipher.Output (40)
        
        # Skip first bits, generated by enumerator
        # which we already pre-calculated
        search = search[2:]
        print ('Even search bits: {}'.format (search[0::2]))
        print ('Odd  search bits: {}'.format (search[1::2]))
        
        # Compute shifted for each
        pipe = Pipeline (0, [0, 0, 0, 0])
        ekeys = pipe.ComputeShifted (0xe9fc7, search[0::2])
        okeys = pipe.ComputeShifted (0x6512c, search[1::2])
                
        # Iterate through possible keys
        for even in ekeys:
            for odd in okeys:

                a = int2binarr (even, 24)
                b = int2binarr (odd, 24)

                # Rotate even right by one
                print (a)
                print (b)
                a = [a[23]] + a[0:23]
                
                # Generate key
                key = [item for sublist in zip(a, b) for item in sublist]

                # TODO: Check XOR
                
                # Instantiate cipher
                cs = Crypto1 (key[::-1])

                # Check results
                out = cs.Output (40)
                if out == verify:
                    cs.Reverse (50)
                    key = cs.State ()[::-1]
                    print ('Found key: {}'.format (hex(binarr2int(key))))
