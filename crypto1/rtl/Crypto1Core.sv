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

   // Solutions obtained using espresso (berkeley)
   // NLFA solution (A,B,C,D)
   // (B&!C&!D) | (A&!B&C) | (A&!B&D) | (C&D) = 1
`define NLFA(A,B,C,D) ((B&~C&~D)|(A&~B&C)|(A&~B&D)|(C&D))
   // NLFB solution (A,B,C,D)
   // (B&C&D) | (A&B&!C) | (!B&C&!D) | (!A&!B&D) = 1
`define NLFB(A,B,C,D) ((B&C&D)|(~B&C&~D)|(~A&B&~D)|(~A&~B&D))
   // NLFC solution (A,B,C,D,E)
   // (!B&!C&!D&E) | (A&B&D) | (!A&!C&D&E) | (A&!B&!E) | (B&C&E) | (B&C&D) = 1
`define NLFC(A,B,C,D,E) ((~B&~C&~D&E)|(A&B&D)|(~A&~C&D&E)|(A&~B&~E)|(B&C&E)|(B&C&D))
   /*
   function logic Compute (logic [19:0] b)
     return `NLFC (`NLFA (b[19:16]), `NLFB (b[15:12]), `NLFA (b[11:8]), `NLFA (b[7:4]), `NLFB (b[3:0]));
   endfunction
    */
`define Compute(b) `NLFC(`NLFA(b[19],b[18],b[17],b[16]), \
                         `NLFB(b[15],b[14],b[13],b[12]), \
                         `NLFA(b[11],b[10],b[9],b[8]), \
                         `NLFA(b[7],b[6],b[5],b[4]), \
                         `NLFB(b[3],b[2],b[1],b[0]) )

   typedef enum logic [2:0] {
                             GENERATE      = 0, // Generate even/odd subkeys
                             EXTEND1       = 1, // Extend 1st bit
                             EXTEND2       = 2, // Extend 2nd bit
                             EXTEND3       = 3, // Extend 3rd bit
                             EXTEND4       = 4, // Extend 4th bit
                             WAIT_COMPLETE = 5
                             } state_t;
   
   typedef enum logic {
                       PROCESS_UP = 0,
                       PROCESS_DN = 1
                       } dir_t;
   
   // Housekeeping
   state_t      state;
   logic        gen_stb;

   // Keep list of potential keys
   logic [23:0] ekey[16];
   logic [23:0] okey[16];
   logic [3:0]  ecnt, ocnt;
   logic signed [5:0] eidx, oidx;   
   logic [4:0]  cnt;

   // Direction to process during extension
   dir_t dir;
   
   // Even bit generation
   logic [23:0]         even;
   B20Enum #(
             .IDX (EIDX))
   u_even
   (
    .CLK (CLK),
    .RESETn (RESETn),
    .BIT_IN (BITSTREAM[0]),
    .STB    (gen_stb),
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
    .STB    (gen_stb),
    .KEY20  (odd[19:0]));

   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= GENERATE;
             gen_stb <= 0;
          end
        else
          begin

             // Push even/odd into ring buffer
             //if (osend
             // State machine
             case (state)
               default:
                 state <= GENERATE;

               GENERATE:
                 begin
                    gen_stb <= 1;
                    state <= EXTEND1;
                    cnt <= 0;
                    eidx <= 0;
                    ecnt <= 0;
                    oidx <= 0;
                    ocnt <= 0;
                 end

               EXTEND1:
                 begin
                    // Clear strobe
                    gen_stb <= 0;

                    // After 2 each switch states
                    if (cnt == 2)
                      begin
                         // Continue if at least one extension worked
                         if ((ecnt > 0) || (ocnt > 0))
                           begin
                              state <= EXTEND2;
                              eidx <= 6'(ecnt) - 1;
                              oidx <= 6'(ocnt) - 1;
                              ecnt <= 0;
                              ocnt <= 0;
                           end
                         // No valid extensions, generate next
                         else
                           state <= GENERATE;
                      end
                    else 
                      begin
                         // Extend even 1 bit
                         if (`Compute( {cnt[0], even[19:1]} ) == BITSTREAM[2])
                           begin
                              $display ("1: even: %05h", {cnt[0], even[19:1]});
                              ekey[ecnt] <= {3'b0, cnt[0], even[19:0]};
                              ecnt <= ecnt + 1;
                           end
                         // Extend odd 1 bit
                         if (`Compute( {cnt[0], odd[19:1]} ) == BITSTREAM[3])
                           begin
                              $display ("1: odd: %05h", {cnt[0], odd[19:1]});
                              okey[ocnt] <= {3'b0, cnt[0], odd[19:0]};
                              ocnt <= ocnt + 1;
                           end
                         cnt <= cnt + 1;
                      end
                 end // case: EXTEND0

               // Extend second bit
               EXTEND2:
                 begin

                    // Check if both are done
                    if ((eidx < 0) && (oidx < 0))
                      begin
                         // No progess, back to generate
                         if ((ocnt == 0) && (ecnt == 0))
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND3;
                              oidx <= 15 - 6'(ocnt);
                              eidx <= 15 - 6'(ecnt);
                              ocnt <= 0;
                              ecnt <= 0;
                           end
                      end
                    else 
                      begin
                         if (eidx > 0)
                           begin
                              // Extend even 1 bit
                              if (`Compute( {cnt[0], ekey[eidx[3:0]][20:2]} ) == BITSTREAM[4])
                                begin
                                   $display ("2: even: %05h", {cnt[0], ekey[eidx[3:0]][20:2]});
                                   ekey[15 - ecnt] <= {2'b0, cnt[0], ekey[eidx[3:0]][20:0]};
                                   ecnt <= ecnt + 1;
                                end
                           end
                         if (oidx > 0)
                           begin
                              // Extend odd 1 bit
                              if (`Compute( {cnt[0], okey[oidx[3:0]][20:2]} ) == BITSTREAM[5])
                                begin
                                   $display ("2: odd: %05h", {cnt[0], okey[oidx[3:0]][20:2]});
                                   okey[15 - ocnt] <= {2'b0, cnt[0], okey[oidx[3:0]][20:0]};
                                   ocnt <= ocnt + 1;
                                end
                           end
                         cnt <= cnt + 1;
                         if (cnt[0])
                           begin
                              eidx <= eidx - 1;
                              oidx <= oidx - 1;
                           end
                      end
                 end // case: EXTEND2

               // Extend third bit
               EXTEND3:
                 begin

                    // Check if both are done
                    if ((eidx > 15) && (oidx > 15))
                      begin
                         // No progess, back to generate
                         if ((ocnt == 0) && (ecnt == 0))
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND4;
                              oidx <= 6'(ocnt) - 1;
                              eidx <= 6'(ecnt) - 1;
                              ocnt <= 0;
                              ecnt <= 0;
                           end
                      end
                    else 
                      begin
                         if (eidx < 15)
                           begin
                              // Extend even 1 bit
                              if (`Compute( {cnt[0], ekey[eidx[3:0]][21:3]} ) == BITSTREAM[6])
                                begin
                                   $display ("3: even: %05h", {cnt[0], ekey[eidx[3:0]][21:3]});
                                   ekey[ecnt] <= {1'b0, cnt[0], ekey[eidx[3:0]][21:0]};
                                   ecnt <= ecnt + 1;
                                end
                           end
                         if (oidx < 15)
                           begin
                              // Extend odd 1 bit
                              if (`Compute( {cnt[0], okey[oidx[3:0]][21:3]} ) == BITSTREAM[7])
                                begin
                                   $display ("3: odd: %05h", {cnt[0], okey[oidx[3:0]][21:3]});
                                   okey[ocnt] <= {1'b0, cnt[0], okey[oidx[3:0]][21:0]};
                                   ocnt <= ocnt + 1;
                                end
                           end
                         cnt <= cnt + 1;
                         if (cnt[0])
                           begin
                              eidx <= eidx + 1;
                              oidx <= oidx + 1;
                           end
                      end
                 end // case: EXTEND3
               
               // Extend fourth bit
               EXTEND4:
                 begin

                    // Check if both are done
                    if ((eidx < 0) && (oidx < 0))
                      begin
                         // No progess, back to generate
                         if ((ocnt == 0) && (ecnt == 0))
                           state <= GENERATE;
                         else
                           begin
                              state <= WAIT_COMPLETE;
                              oidx <= 15 - 6'(ocnt);
                              eidx <= 15 - 6'(ecnt);
                              //ocnt <= 0;
                              //ecnt <= 0;
                           end
                      end
                    else 
                      begin
                         if (eidx > 0)
                           begin
                              // Extend even 1 bit
                              if (`Compute( {cnt[0], ekey[eidx[3:0]][22:4]} ) == BITSTREAM[8])
                                begin
                                   $display ("4: even: %05h", {cnt[0], ekey[eidx[3:0]][22:4]});
                                   ekey[15 - ecnt] <= {cnt[0], ekey[eidx[3:0]][22:0]};
                                   ecnt <= ecnt + 1;
                                end
                           end
                         if (oidx > 0)
                           begin
                              // Extend odd 1 bit
                              if (`Compute( {cnt[0], okey[oidx[3:0]][22:4]} ) == BITSTREAM[9])
                                begin
                                   $display ("4: odd: %05h", {cnt[0], okey[oidx[3:0]][22:4]});
                                   okey[15 - ocnt] <= {cnt[0], okey[oidx[3:0]][22:0]};
                                   ocnt <= ocnt + 1;
                                end
                           end
                         cnt <= cnt + 1;
                         if (cnt[0])
                           begin
                              eidx <= eidx - 1;
                              oidx <= oidx - 1;
                           end
                      end
                 end // case: EXTEND4

               WAIT_COMPLETE:
                 begin

                    // Wait for all elements to go into ring buffer
                    // Kick off ring buffer comparison
                    // Restart extension while ring buffer comparison completes
                    state <= WAIT_COMPLETE;
                 end
              
             endcase // case (state)
             
          end // else: !if(~RESETn)
        
     end // always @ (posedge CLK)
      

endmodule // Crypto1Core
