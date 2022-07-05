/**
 * Test bench for normal Crypto1 routine.
 * 
 * Elliot Buller
 * 2022
 */

module Crypto1_tb
  (
   input               CLK,
   input               RESETn,
   input [47:0]        KEY,
   output logic [47:0] OUTPUT,
   output logic        DONE
   );

   
   typedef enum [1:0] {
                       LOAD_KEY = 0,
                       RUN      = 1,
                       COMPLETE = 2
                       } state_t;
   state_t state;
   logic              init, stb, out;
   logic [5:0]        ctr;

   // Crypto1 core
   Crypto1 u_c1 (
                 .CLK    (CLK),
                 .RESETn (RESETn),
                 .KEY    (KEY),
                 .INIT   (init),
                 .STB    (stb),
                 .OUTPUT (out));
   
   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= LOAD_KEY;
             init <= 0;
             stb <= 0;
             ctr <= 0;
             DONE <= 0;
          end
        else
          begin
             case (state)
               default:
                 state <= COMPLETE;

               LOAD_KEY:
                 begin
                    init <= 1;
                    state <= RUN;
                    OUTPUT <= '0;
                 end

               RUN:
                 begin
                    if (ctr == 6'd48)
                      state <= COMPLETE;
                    if (stb)
                      begin
                         OUTPUT <= {OUTPUT[46:0], out};
                         ctr <= ctr + 1;
                      end
                    else
                      begin
                         init <= 0;
                         stb <= 1;
                      end
                 end // case: RUN
               
               COMPLETE:
                 DONE <= 1;
               
             endcase // case (state)
          end
     end
endmodule // Crypto1_tb
