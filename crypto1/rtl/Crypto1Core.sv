/**
 *
 * Single Crypto1 core instance
 * Takes bitstream, even index (0,15)
 * odd index (0,15)
 * 
 * Generates and searches potential keys within 1/256 key subspace
 *
 * Elliot Buller
 * 2022
 */

module Crypto1Core #(
    parameter [3:0] EIDX,
    parameter [3:0] OIDX
    ) (
       input               CLK,
       input               RESETn,
       input [47:0]        BITSTREAM,
       output logic [47:0] KEY,
       output logic        DONE
   );

   // State machine
   typedef enum            logic [2:0] {
                                        GEN_SUBKEY  = 0,
                                        WAIT_SUBKEY = 1,
                                        COMPARE = 2
                                        } state_t;
   state_t state;

   /*
   // Even subkeys
   logic [23:0]            even_rddata;
   logic                   even_rden, even_rdempty;
   logic                   even_done;

   // Read when available
   always even_rden = ~even_rdempty;

   // Even subkey generator
   GenSubkey #( .IDX (EIDX) )
   u_even (
           .CLK            (CLK),
           .RESETn         (RESETn),
           .BITSTREAM      (5'b01100), // Forward = 00110
           .SUBKEY_RDEN    (even_rden),
           .SUBKEY_RDDATA  (even_rddata),
           .SUBKEY_RDEMPTY (even_rdempty),
           .DONE           (even_done)
           );
    */
   // Odd subkeys
   logic [23:0]            odd_rddata;
   logic                   odd_rden, odd_rdempty;
   logic                   odd_done;

   // Read when available
   always odd_rden = ~odd_rdempty;

   // Odd subkey generator
   GenSubkey #( .IDX (OIDX) )
   u_odd (
           .CLK            (CLK),
           .RESETn         (RESETn),
           .BITSTREAM      (5'b10011), // Forward = 11001
           .SUBKEY_RDEN    (odd_rden),
           .SUBKEY_RDDATA  (odd_rddata),
           .SUBKEY_RDEMPTY (odd_rdempty),
           .DONE           (odd_done)
           );

   /*
   always @(posedge CLK)
     begin
     end
    */
endmodule // Crypto1Core
