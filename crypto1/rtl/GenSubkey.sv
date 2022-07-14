/**
 *
 * Generate 24bit potential subkey given 5 bits of bitstream
 *
 * Elliot Buller
 * 2022
 */

module GenSubkey 
  (
   input               CLK,
   input               RESETn,
   input [4:0]         BITSTREAM,
   input [3:0]         IDX,
   // Finished enumerating subkeys
   output logic        DONE,
   // Output FIFO of subkeys
   output logic [23:0] SUBKEY_RDDATA,
   input               SUBKEY_RDEN,
   output logic        SUBKEY_RDEMPTY
   );

   typedef enum logic [2:0] {
                             GENERATE      = 0, // Generate even/odd subkeys
                             EXTEND1       = 1, // Extend 1st bit
                             EXTEND2       = 2, // Extend 2nd bit
                             EXTEND3       = 3, // Extend 3rd bit
                             EXTEND4       = 4  // Extend 4th bit
                             } state_t;

`include "crypto1.vh"
   
   // Housekeeping
   state_t      state;
   logic        gen_stb;
   logic        done;
   
   // Keep list of potential keys
   logic signed [4:0] idx;
   logic [1:0]  ctr;
   logic [3:0]  cnt;
   
   // Temp subkey extension buffer
   logic [23:0] subkey [8];

   // Generated 20bit enumerator output
   logic [19:0] k20;

   // Fifo signals
   logic        fifo_wren, fifo_wrfull, fifo_write;
   logic [23:0] fifo_wrdata;


   // 20 bit key enumerator
   B20Enum
     u_b20
       (
        .CLK    (CLK),
        .RESETn (RESETn),
        .BIT_IN (BITSTREAM[0]),
        .IDX    (IDX),
        .STB    (gen_stb),
        .KEY20  (k20),
        .DONE   (done));

   // Output FIFO
   fifo #(
          .DATA_WIDTH   (24),
          .DEPTH_WIDTH  (5))
   u_fifo_subkey
     (
      .clk       (CLK),
      .rst       (~RESETn),
      .wr_en_i   (fifo_wren),
      .wr_data_i (fifo_wrdata),
      .full_o    (fifo_wrfull),
      .rd_en_i   (SUBKEY_RDEN),
      .rd_data_o (SUBKEY_RDDATA),
      .empty_o   (SUBKEY_RDEMPTY)
      );

   // Suppress writes as soon as fifo is full
   always fifo_wren = fifo_write & ~fifo_wrfull;
   
   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= GENERATE;
             gen_stb <= 0;
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
                    // Strobe generated, start producing subkeys
                    if (gen_stb)
                      begin
                         gen_stb <= 0;
                         state <= EXTEND1;

                         // Clear DONE signal
                         DONE <= 0;

                         //$display ("k20=%05x", k20[19:0]);
                      end

                    // Generate strobe
                    else if (~done)
                      begin
                         gen_stb <= 1;
                         ctr <= 0;
                         idx <= 0;
                         cnt <= 0;
                      end
                    
                    // End of generation
                    else
                      DONE <= 1;                              
                 end

               EXTEND1:
                 begin

                    // After 2 cycles switch states
                    if (ctr == 2)
                      begin
                         // Continue if at least one extension worked
                         if (cnt > 0)
                           begin
                              state <= EXTEND2;
                              idx <= 5'(cnt) - 1;
                              cnt <= 0;
                              ctr <= 0;
                           end
                         // No valid extensions, generate next
                         else
                           state <= GENERATE;
                      end
                    else 
                      begin
                         
                         // Extend 1 bit
                         if (`ComputeSub( {k20[18:0], ctr[0]} ) == BITSTREAM[1])
                           begin
                              //$display ("1: %06h", {3'b0, k20[19:0], ctr[0]});
                              subkey[cnt[2:0]] <= {3'b0, k20[19:0], ctr[0]};
                              cnt <= cnt + 1;
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
                         if (cnt == 0)
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND3;
                              idx <= 8 - 5'(cnt);
                              cnt <= 0;
                              ctr <= 0;
                           end
                      end
                    else
                      begin
                         if (idx >= 0)
                           begin
                              // Extend even 1 bit
                              if (`ComputeSub( {subkey[idx[2:0]][18:0], ctr[0]} ) == BITSTREAM[2])
                                begin
                                   //$display ("2: %06h", {2'b0, subkey[idx[2:0]][20:0], ctr[0]});
                                   subkey[7 - cnt[2:0]] <= {2'b0, subkey[idx[2:0]][20:0], ctr[0]};
                                   cnt <= cnt + 1;
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
                    if (idx > 7)
                      begin
                         // No progess, back to generate
                         if (cnt == 0)
                           state <= GENERATE;
                         else
                           begin
                              state <= EXTEND4;
                              idx <= 5'(cnt) - 1;
                              cnt <= 0;
                              ctr <= 0;
                           end
                      end
                    else
                      begin
                         if (idx <= 7)
                           begin
                              // Extend even 1 bit                                             
                              if (`ComputeSub( {subkey[idx[2:0]][18:0], ctr[0]} ) == BITSTREAM[3])
                                begin
                                   //$display ("3: %06h", {1'b0, subkey[idx[2:0]][21:0], ctr[0]});
                                   subkey[cnt[2:0]] <= {1'b0, subkey[idx[2:0]][21:0], ctr[0]};
                                   cnt <= cnt + 1;
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
                         // Stop FIFO write
                         fifo_write <= 0;
                         state <= GENERATE;
                      end
                    else
                      begin
                         // Pump fifo until full
                         if (~fifo_wrfull)
                           begin
                              if (idx >= 0)
                                begin
                                   // Extend even 1 bit
                                   if (`ComputeSub( {subkey[idx[2:0]][18:0], ctr[0]} ) == BITSTREAM[4])
                                     begin
                                        //$display ("4: %06h", {subkey[idx[2:0]][22:0], ctr[0]});
                                        fifo_wrdata <= {subkey[idx[2:0]][22:0], ctr[0]};
                                        fifo_write <= 1;
                                     end
                                   else
                                     fifo_write <= 0;
                                end
                              ctr <= ctr + 1;
                              if (ctr[0])
                                begin
                                   idx <= idx - 1;
                                end
                           end // if (~fifo_wrfull)
                      end
                 end // case: EXTEND4

             endcase // case (state)
             
          end // else: !if(~RESETn)
        
     end // always @ (posedge CLK)
      
endmodule // GenSubkey
