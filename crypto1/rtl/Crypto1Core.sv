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
                             GENERATE      = 0, // Generate even/odd
                             EXTEND0       = 1, // Extend 1 bit
                             EXTENDn       = 2, // Extend 3 bits
                             WAIT_COMPLETE = 3
                             } state_t;
   

   // Housekeeping
   state_t      state;
   logic        gen_stb;

   // Keep list of potential keys
   logic [23:0] ekey[16];
   logic [23:0] okey[16];
   logic [3:0]  eidx, ecnt, esent;
   logic [3:0]  oidx, ocnt, osent;
   logic [3:0]  cnt;
   logic [2:0]  bit_ext;
   
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
                    state <= EXTEND0;
                    cnt <= 0;
                    eidx <= 0;
                    ecnt <= 0;
                    oidx <= 0;
                    ocnt <= 0;
                    esent <= 0;
                    osent <= 0;
                 end

               EXTEND0:
                 begin
                    // Clear strobe
                    gen_stb <= 0;

                    // After 2 each switch states
                    if (cnt == 2)
                      begin
                         state <= EXTENDn;
                         cnt <= 0;
                         bit_ext <= 1;
                      end
                    else 
                      begin
                         // Extend even 1 bit
                         $display ("data: %05h", {cnt[0], even[19:1]});
                         if (`Compute( {cnt[0], even[19:1]} ) == BITSTREAM[2])
                           begin
                              ekey[ecnt] = {3'b0, cnt[0], even[19:0]};
                              ecnt <= ecnt + 1;
                           end
                         // Extend odd 1 bit
                         if (`Compute( {cnt[0], odd[19:1]} ) == BITSTREAM[3])
                           begin
                              okey[ocnt] = {3'b0, cnt[0], odd[19:0]};
                              ocnt <= ocnt + 1;
                           end
                         cnt <= cnt + 1;
                      end
                 end // case: EXTEND0

               EXTENDn:
                 state <= WAIT_COMPLETE;

               /*
               // Loop over list for the rest of the extensions
               // Reading data will happem from the inside toward the outside
               // Writing data from the opposite side in. This allows conserving
               // memory for intermediate data
               EXTENDn:
                 begin

                    // All done, generate next
                    if (bit_ext == 4)
                      state <= WAIT_COMPLETE;
                    // Bit extension done, next bit
                    else if ((eidx == ecnt) && (oidx == ocnt))
                      begin
                         bit_ext <= bit_ext + 1;        
                         cnt <= 0;
                         eidx <= 0;
                         oidx <= 0;
                      end
                    else
                      begin
                          // Add even
                         if (`Compute( '{cnt[0], ekey[20+bit_ext:1+bit_ext][eidx]} ))
                           begin
                              ekey[ecnt] = '{bit_ext{{0}}, cnt[0], ekey[20+bit_ext:0][eidx]};
                              ecnt <= ecnt + 1;
                              eidx <= eidx + 1;
                           end
                         // Add odd
                         if (`Compute ('{cnt[0], okey[20+bit_ext:1+bit_ext][oidx]} ))
                           begin
                              okey[ocnt] = okey[20+bit_ext:1+bit_ext][odix]};
                              ocnt <= ocnt + 1;
                              oidx <= oidx + 1;
                           end
                         cnt <= cnt + 1;
                      end
                 end // case: EXTENDn
               */
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
