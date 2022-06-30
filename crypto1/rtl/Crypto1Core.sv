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

   
   // Even subkeys
   logic [23:0]            even [16];
   logic [3:0]             ecnt;
   logic                   evalid, eready;
   logic                   edone;

   // Even subkey generator
   GenSubkey #( .IDX (EIDX) )
   u_even (
           .CLK       (CLK),
           .RESETn    (RESETn),
           .BITSTREAM ({BITSTREAM[0], 
                        BITSTREAM[2],
                        BITSTREAM[4],
                        BITSTREAM[6],
                        BITSTREAM[8]}),
           .SUBKEY    (even),
           .CNT       (ecnt),
           .VALID     (evalid),
           .READY     (eready),
           .DONE      (edone)
           );

   
   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             eready <= 0;
          end
        else
          begin

             case (state)

               default:
                 state <= GEN_SUBKEY;

               GEN_SUBKEY:
                 begin
                    eready <= 1;
                    state <= WAIT_SUBKEY;
                 end

               WAIT_SUBKEY:
                 begin
                    if (evalid)
                      begin
                         eready <= 0;
                         state <= COMPARE;
                      end
                 end

               COMPARE:
                 begin
                    if (edone)
                      $display ("DONE");
                    else
                      state <= GEN_SUBKEY;
                 end
             endcase // case (state)
             
          end
     end

endmodule // Crypto1Core
