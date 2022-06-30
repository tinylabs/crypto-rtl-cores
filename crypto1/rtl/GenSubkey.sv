/**
 *
 * Generate 24bit potential subkey given 5 bits of bitstream
 *
 * Elliot Buller
 * 2022
 */

module GenSubkey #(
                   parameter [3:0] IDX
                   ) (
       input               CLK,
       input               RESETn,
       input [4:0]         BITSTREAM,
       output logic [23:0] SUBKEY [16],
       output logic [3:0]  CNT,
       output logic        VALID,
       input               READY,
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
   // Compute NLF output from 20 bit input
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
                             EXTEND4       = 4  // Extend 4th bit
                             } state_t;
   
   // Direction to process during extension
   typedef enum logic {
                       PROCESS_UP = 0,
                       PROCESS_DN = 1
                       } dir_t;
   dir_t dir;
   
   // Housekeeping
   state_t      state;
   logic        gen_stb;
   logic        done;
   
   // Keep list of potential keys
   logic signed [5:0] idx;
   logic [4:0]  ctr;
   
   // Generated 20bit subkey
   logic [19:0] k20;
   
   // 20 bit key enumerator
   B20Enum #(
             .IDX (IDX))
   u_b20
   (
    .CLK    (CLK),
    .RESETn (RESETn),
    .BIT_IN (BITSTREAM[0]),
    .STB    (gen_stb),
    .KEY20  (k20),
    .DONE   (done));

   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= GENERATE;
             gen_stb <= 0;
             VALID <= 0;
             DONE <= 0;
          end
        else
          begin

             // State machine
             case (state)
               default:
                 state <= GENERATE;

               GENERATE:
                 begin
                    if (READY)
                      begin
                         VALID <= 0;
                         gen_stb <= 1;
                         state <= EXTEND1;
                         ctr <= 0;
                         idx <= 0;
                         CNT <= 0;
                      end
                 end

               EXTEND1:
                 begin
                    // Clear strobe
                    gen_stb <= 0;

                    // After 2 each switch states
                    if (ctr == 2)
                      begin
                         // Continue if at least one extension worked
                         if (CNT > 0)
                           begin
                              state <= EXTEND2;
                              idx <= 6'(CNT) - 1;
                              CNT <= 0;
                              ctr <= 0;
                           end
                         // No valid extensions, generate next
                         else
                           state <= GENERATE;
                      end
                    else 
                      begin
                         // Extend 1 bit
                         if (`Compute( {ctr[0], k20[19:1]} ) == BITSTREAM[1])
                           begin
                              //$display ("1: %05h", {ctr[0], k20[19:1]});
                              SUBKEY[CNT] <= {3'b0, ctr[0], k20[19:0]};
                              CNT <= CNT + 1;
                           end
                         ctr <= ctr + 1;
                      end
                 end // case: EXTEND1

               EXTEND2:
                 begin

                    // Check if both are done
                    if (idx < 0)
                      begin
                         // No progess, back to generate
                         if (CNT == 0)
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND3;
                              idx <= 15 - 6'(CNT);
                              CNT <= 0;
                              ctr <= 0;
                           end
                      end
                    else
                      begin
                         if (idx > 0)
                           begin
                              // Extend even 1 bit
                              if (`Compute( {ctr[0], SUBKEY[idx[3:0]][20:2]} ) == BITSTREAM[2])
                                begin
                                   //$display ("2: %05h", {ctr[0], SUBKEY[idx[3:0]][20:2]});
                                   SUBKEY[15 - CNT] <= {2'b0, ctr[0], SUBKEY[idx[3:0]][20:0]};
                                   CNT <= CNT + 1;
                                end
                           end
                         ctr <= ctr + 1;
                         if (ctr[0])
                           begin
                              idx <= idx - 1;
                           end
                      end
                 end // case: EXTEND2

               EXTEND3:
                 begin

                    // Check if both are done
                    if (idx > 15)
                      begin
                         // No progess, back to generate
                         if (CNT == 0)
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND4;
                              idx <= 6'(CNT) - 1;
                              CNT <= 0;
                              ctr <= 0;
                           end
                      end
                    else
                      begin
                         if (idx < 15)
                           begin
                              // Extend even 1 bit                                             
                              if (`Compute( {ctr[0], SUBKEY[idx[3:0]][21:3]} ) == BITSTREAM[3])
                                begin
                                   //$display ("3: %05h", {CNT[0], SUBKEY[idx[3:0]][21:3]});
                                   SUBKEY[CNT] <= {1'b0, ctr[0], SUBKEY[idx[3:0]][21:0]};
                                   CNT <= CNT + 1;
                                end
                           end
                         ctr <= ctr + 1;
                         if (ctr[0])
                           begin
                              idx <= idx + 1;
                           end
                      end
                 end // case: EXTEND3

               EXTEND4:
                 begin

                    // Check if both are done
                    if (idx < 0)
                      begin
                         // No progess, back to generate
                         if (CNT == 0)
                           state <= GENERATE;
                         else
                           begin
                              state <= GENERATE;
                              idx <= 15 - 6'(CNT);
                              VALID <= 1;
                              if (done)
                                DONE <= 1;
                           end
                      end
                    else
                      begin
                         if (idx > 0)
                           begin
                              // Extend even 1 bit                                                                                                                             
                              if (`Compute( {ctr[0], SUBKEY[idx[3:0]][22:4]} ) == BITSTREAM[4])
                                begin
                                   $display ("4: %05h", {ctr[0], SUBKEY[idx[3:0]][22:4]});
                                   SUBKEY[15 - CNT] <= {ctr[0], SUBKEY[idx[3:0]][22:0]};
                                   CNT <= CNT + 1;
                                end
                           end
                         ctr <= ctr + 1;
                         if (ctr[0])
                           begin
                              idx <= idx - 1;
                           end
                      end
                 end // case: EXTEND4

             endcase // case (state)
             
          end // else: !if(~RESETn)
        
     end // always @ (posedge CLK)
      
endmodule // GenSubkey
