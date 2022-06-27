/**
 *
 * Single Crypto1 core instance
 * Takes bitstream, even index (0,15)
 * odd index (0,15)
 * 
 * Generates potential keys
 *
 * Elliot Buller
 * 2022
 */

module Crypto1Core 
  #(
    parameter [3:0] EIDX,
    parameter [3:0] OIDX)
   (
    input               CLK,
    input               RESETn,
    input [47:0]        BITSTREAM,
    output logic [47:0] KEY
   );

   // Even bit generation
   logic [23:0]         even;
   B20Enum #(
             .IDX (EIDX))
   u_even
   (
    .CLK (CLK),
    .RESETn (RESETn),
    .BIT_IN (BITSTREAM[0]),
    .STB    (1'b1),
    .KEY20  (even[19:0]));

   // Odd bit generation
   logic [23:0]         odd;
   B20Enum #(
             .IDX (OIDX))
   u_odd
   (
    .CLK (CLK),
    .RESETn (RESETn),
    .BIT_IN (BITSTREAM[1]),
    .STB    (1'b1),
    .KEY20  (odd[19:0]));

   // Extend even/odd keys by 4bits
   

endmodule // Crypto1Core
