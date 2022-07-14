#!/bin/env python3
#
# Flexsoc python interface
#

import serial
import time
from struct import pack, unpack

class Flexsoc (object):

    plen = { 'rb' : 3, 'rh' : 3, 'rw' : 3,
             'wb' : 4, 'wh' : 5, 'ww' : 6};
    
    def __init__ (self, device):

        try:
            # Create serial device
            self.ser = serial.Serial (device,
                                      12000000,
                                      serial.EIGHTBITS,
                                      serial.PARITY_NONE,
                                      serial.STOPBITS_ONE)
            self.ser.flushInput ()
            self.ser.flushOutput ()
            time.sleep (0.5)
        except serial.SerialException as e:
            print ('Unable to open device: {}'.format (device))
            raise e

    # Context manager
    def __enter__ (self):
        return self

    def __exit__ (self, type, value, traceback):
        self.ser.close ()

    def Close (self):
        self.ser.close ()
        
    def Control (self, typ):
        ctl = 0x80
        if typ[0] == 'w':
            ctl |= 0x8
        ctl |= Flexsoc.plen[typ] << 4
        if typ[1] == 'h':
            ctl |= 1
        elif typ[1] == 'w':
            ctl |= 2
        return ctl

    def CheckResp (self, rv=None):
        if rv:
            if rv & 1:
                print ('Access Error: {}'.format (hex (rv)))
                raise IOError            
        else:
            rv = int.from_bytes(self.ser.read (1), 'big')
            if rv != 0x80:
                print ('Invalid response: {}'.format (hex (rv)))
                raise IOError

    # Memory access functions
    def WriteWord (self, addr, val):
        self.ser.write (pack ('>BII', self.Control ('ww'), addr, val))
        self.CheckResp ()
        
    def WriteHalf (self, addr, val):
        self.ser.write (pack ('>BIH', self.Control ('wh'), addr, val))
        self.CheckResp ()
        
    def WriteByte (self, addr, val):
        self.ser.write (pack ('>BIB', self.Control ('wb'), addr, val))
        self.CheckResp ()
        
    def ReadWord (self, addr):
        self.ser.write (pack ('>BI', self.Control ('rw'), addr))
        rv, val = unpack ('>BI', self.ser.read (5))
        self.CheckResp (rv)
        return val

    def ReadHalf (self, addr):
        self.ser.write (pack ('>BI', self.Control ('rh'), addr))
        rv, val = unpack ('>BH', self.ser.read (3))
        self.CheckResp (rv)
        return val

    def ReadByte (self, addr):
        self.ser.write (pack ('>BI', self.Control ('rb'), addr))
        rv, val = unpack ('>BB', self.ser.read (2))
        self.CheckResp (rv)
        return val

if __name__ == '__main__':

    with Flexsoc ('/dev/ttyUSB1') as fs:
        print (hex(fs.ReadWord (0)))
        
