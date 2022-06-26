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
  (
   input               CLK,
   input               RESETn,
   input [47:0]        BITSTREAM,
   input [3:0]         EIDX,
   input [3:0]         OIDX,
   output logic [47:0] KEY
   );


endmodule // Crypto1Core
