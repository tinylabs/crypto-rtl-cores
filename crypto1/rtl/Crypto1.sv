/**
 *
 * Crypto1 normal operation - Initialize with key. Generate one output bit per strobe.
 * 
 * Elliot Buller
 * 2022
 */

module Crypto1
  (
   input        CLK,
   input        RESETn,
   input [47:0] KEY,
   input        INIT,
   input        STB,
   output logic OUTPUT
   );

`include "crypto1.vh"
   
   // Internal state
   logic [47:0] lfsr;

   always @(posedge CLK)
     begin
        if (~RESETn)
          lfsr <= 0;
        else if (INIT)
          lfsr <= KEY;
        else if (STB)
          begin
             lfsr <= {lfsr[46:0],
                      lfsr[47] ^ lfsr[42] ^ lfsr[38] ^ lfsr[37] ^
                      lfsr[35] ^ lfsr[33] ^ lfsr[32] ^ lfsr[30] ^
                      lfsr[28] ^ lfsr[23] ^ lfsr[22] ^ lfsr[20] ^
                      lfsr[18] ^ lfsr[12] ^ lfsr[8] ^ lfsr[6] ^
                      lfsr[5] ^ lfsr[4]};
             OUTPUT <= `Compute (lfsr);
             // Debug
             $display ("state: %06x", lfsr);
             $display ("NLA(%d)=%d", { lfsr[0],lfsr[2],lfsr[4],lfsr[6] },
                       `NLFA(lfsr[0],lfsr[2],lfsr[4],lfsr[6]));
             $display ("NLB(%d)=%d", { lfsr[8],lfsr[10],lfsr[12],lfsr[14] },
                       `NLFB(lfsr[8],lfsr[10],lfsr[12],lfsr[14]));
             $display ("NLA(%d)=%d", { lfsr[16],lfsr[18],lfsr[20],lfsr[22] },
                       `NLFA(lfsr[16],lfsr[18],lfsr[20],lfsr[22]));
             $display ("NLA(%d)=%d", { lfsr[24],lfsr[26],lfsr[28],lfsr[30] },
                       `NLFA(lfsr[24],lfsr[26],lfsr[28],lfsr[30]));
             $display ("NLB(%d)=%d", { lfsr[32],lfsr[34],lfsr[36],lfsr[38] },
                       `NLFB(lfsr[32],lfsr[34],lfsr[36],lfsr[38]));
             $display ("NLC(%d)=%d", {`NLFA(lfsr[0],lfsr[2],lfsr[4],lfsr[6]),
                                      `NLFB(lfsr[8],lfsr[10],lfsr[12],lfsr[14]),
                                      `NLFA(lfsr[16],lfsr[18],lfsr[20],lfsr[22]),
                                      `NLFA(lfsr[24],lfsr[26],lfsr[28],lfsr[30]),
                                      `NLFB(lfsr[32],lfsr[34],lfsr[36],lfsr[38])},
                       `NLFC(`NLFA(lfsr[0],lfsr[2],lfsr[4],lfsr[6]),
                             `NLFB(lfsr[8],lfsr[10],lfsr[12],lfsr[14]),
                             `NLFA(lfsr[16],lfsr[18],lfsr[20],lfsr[22]),
                             `NLFA(lfsr[24],lfsr[26],lfsr[28],lfsr[30]),
                             `NLFB(lfsr[32],lfsr[34],lfsr[36],lfsr[38])));
          end
     end
   
endmodule // Crypto1

