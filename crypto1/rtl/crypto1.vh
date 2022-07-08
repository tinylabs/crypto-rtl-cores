`ifndef _crypto1_vh_
 `define _crypto1_vh_

   // Solutions obtained using espresso (berkeley)
   // NLFA solution fn=0x9E98 (A,B,C,D)
   // (B&!C&!D) | (A&!B&C) | (A&!B&D) | (C&D) = 1
`define NLFA(A,B,C,D) ((B&~C&~D)|(A&~B&C)|(A&~B&D)|(C&D))

   // NLFB solution fn=0xB48E (A,B,C,D)
   // (B&C&D) | (A&B&!C) | (!B&C&!D) | (!A&!B&D) = 1
`define NLFB(A,B,C,D) ((B&C&D)|(A&B&~C)|(~B&C&~D)|(~A&~B&D))

   // NLFC solution (A,B,C,D,E)
   // (!B&!C&!D&E) | (A&B&D) | (!A&!C&D&E) | (A&!B&!E) | (B&C&E) | (B&C&D) = 1
`define NLFC(A,B,C,D,E) ((~B&~C&~D&E)|(A&B&D)|(~A&~C&D&E)|(A&~B&~E)|(B&C&E)|(B&C&D))

   // Compute NLF output from 40 bit input
`define Compute(b) `NLFC(`NLFA(b[0],b[2],b[4],b[6]),     \
                         `NLFB(b[8],b[10],b[12],b[14]),  \
                         `NLFA(b[16],b[18],b[20],b[22]), \
                         `NLFA(b[24],b[26],b[28],b[30]), \
                         `NLFB(b[32],b[34],b[36],b[38]))

   // Compute NLF output from 20 bit input
`define ComputeSub(b) `NLFC(`NLFA(b[0],b[1],b[2],b[3]),     \
                            `NLFB(b[4],b[5],b[6],b[7]),  \
                            `NLFA(b[8],b[9],b[10],b[11]), \
                            `NLFA(b[12],b[13],b[14],b[15]), \
                            `NLFB(b[16],b[17],b[18],b[19]))

`define XOR_OK(b) ((b[47] ^ b[42] ^ b[38] ^ b[37] ^ \
                    b[35] ^ b[33] ^ b[32] ^ b[30] ^ \
                    b[28] ^ b[23] ^ b[22] ^ b[20] ^ \
                    b[18] ^ b[12] ^ b[8] ^ b[6] ^   \
                    b[5] ^ b[4] ^ b[0]) == 0)
`endif
