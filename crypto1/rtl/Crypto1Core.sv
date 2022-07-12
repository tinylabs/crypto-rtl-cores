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
                     parameter [3:0] OIDX,
                     parameter RING_DEPTH
    ) (
       input        CLK,
       input        RESETn,
       input [47:0] BITSTREAM,
       output logic DONE,
       // Clock out key data using serial stream
       output logic KEY_DATA,
       input        KEY_CLK,
       output logic KEY_VALID
   );

`include "crypto1.vh"

   // LFSR taps       765432109876543210987654321098765432109876543210
   parameter TAPS=48'b100001000110101101010000110101000001000101110000;
   
   // State machine
   typedef enum            logic [1:0] {
                                        WAIT_FULL   = 0,
                                        COMPARE     = 1,
                                        WAIT_FINISH = 2,
                                        FINISHED    = 3
                                        } state_t;
   state_t state;

   // Even subkeys
   logic [23:0]            efifo_rddata, even_subkey;
   logic                   efifo_rden, efifo_rdempty;
   logic                   even_done;

   // Ring buffer signals
   logic                   ring_rden, ring_full, ring_done;
   logic                   ring_reset_n, ring_end, ring_valid;
   
   logic [$clog2(RING_DEPTH):0] ridx;
 
   // Even subkey generator
   GenSubkey #( .IDX (EIDX) )
   u_even (
           .CLK            (CLK),
           .RESETn         (RESETn),
           .BITSTREAM      ({BITSTREAM[39],
                             BITSTREAM[41],
                             BITSTREAM[43],
                             BITSTREAM[45],
                             BITSTREAM[47]}),
           .SUBKEY_RDEN    (efifo_rden),
           .SUBKEY_RDDATA  (efifo_rddata),
           .SUBKEY_RDEMPTY (efifo_rdempty),
           .DONE           (even_done)
           );

   // Ring buffer connector to subkey generator
   RingBuf #(
             .DEPTH (RING_DEPTH),
             .WIDTH (24))
   u_even_ring (
                .CLK          (CLK),
                .RESETn       (ring_reset_n & RESETn),
                .FIFO_RDDATA  (efifo_rddata),
                .FIFO_RDEN    (efifo_rden),
                .FIFO_RDEMPTY (efifo_rdempty),
                .FIFO_DONE    (even_done),
                .RDEN         (ring_rden),
                .RDDATA       (even_subkey),
                .FULL         (ring_full),
                .DONE         (ring_done),
                .END          (ring_end)
                );
   
   // Odd subkeys
   logic [23:0]            odd_subkey;
   logic                   ofifo_rden, ofifo_rdempty;
   logic                   odd_done, odd_full, odd_reset_n;
   logic [47:0]            key, key_save;
   
   // Odd subkey generator
   GenSubkey #( .IDX (OIDX) )
   u_odd (
           .CLK            (CLK),
           .RESETn         (RESETn & odd_reset_n),
           .BITSTREAM      ({BITSTREAM[38],
                             BITSTREAM[40],
                             BITSTREAM[42],
                             BITSTREAM[44],
                             BITSTREAM[46]}),
           .SUBKEY_RDEN    (ofifo_rden),
           .SUBKEY_RDDATA  (odd_subkey),
           .SUBKEY_RDEMPTY (ofifo_rdempty),
           .DONE           (odd_done)
           );

   logic [51:0]            lfsr [10];
   logic [10:0]            valid;
   genvar                  j, k;

   // Copy over 48 bits from previous state
   // and generate 4 new bits
   generate for (j = 1; j < 10; j = j + 1)
     begin : GEN_LFSR_NEXT
        always @(posedge CLK)
          lfsr[j][51:4] <= lfsr[j-1][47:0];
        
        // Generate extended bits
        for (k = 0; k < 4; k = k + 1)
          always @(posedge CLK)
            lfsr[j][3-k] <= ^((TAPS >> k) & lfsr[j-1][47:0]);
     end
   endgenerate

   // Generate 38 bit bitstream from lfsr[0-7]
   logic [3:0]  match0;
   logic [7:0]  match1;
   logic [11:0] match2;
   logic [15:0] match3;
   logic [19:0] match4;
   logic [23:0] match5;
   logic [27:0] match6;
   logic [31:0] match7;
   logic [35:0] match8;
   logic [37:0] match9;

   // Note: These intermediate wires are required for vivado synth
   logic [47:0] b0, b1, b2, b3, b4, b5, b6, b7, b8, b9;
   logic [47:0] b10, b11, b12, b13, b14, b15, b16, b17, b18, b19;
   logic [47:0] b20, b21, b22, b23, b24, b25, b26, b27, b28, b29;
   logic [47:0] b30, b31, b32, b33, b34, b35, b36, b37;
   assign b0 = lfsr[0][50:3];
   assign b1 = lfsr[0][49:2];
   assign b2 = lfsr[0][48:1];
   assign b3 = lfsr[0][47:0];
   assign b4 = lfsr[1][50:3];
   assign b5 = lfsr[1][49:2];
   assign b6 = lfsr[1][48:1];
   assign b7 = lfsr[1][47:0];
   assign b8 = lfsr[2][50:3];
   assign b9 = lfsr[2][49:2];
   assign b10 = lfsr[2][48:1];
   assign b11 = lfsr[2][47:0];
   assign b12 = lfsr[3][50:3];
   assign b13 = lfsr[3][49:2];
   assign b14 = lfsr[3][48:1];
   assign b15 = lfsr[3][47:0];
   assign b16 = lfsr[4][50:3];
   assign b17 = lfsr[4][49:2];
   assign b18 = lfsr[4][48:1];
   assign b19 = lfsr[4][47:0];
   assign b20 = lfsr[5][50:3];
   assign b21 = lfsr[5][49:2];
   assign b22 = lfsr[5][48:1];
   assign b23 = lfsr[5][47:0];
   assign b24 = lfsr[6][50:3];
   assign b25 = lfsr[6][49:2];
   assign b26 = lfsr[6][48:1];
   assign b27 = lfsr[6][47:0];
   assign b28 = lfsr[7][50:3];
   assign b29 = lfsr[7][49:2];
   assign b30 = lfsr[7][48:1];
   assign b31 = lfsr[7][47:0];
   assign b32 = lfsr[8][50:3];
   assign b33 = lfsr[8][49:2];
   assign b34 = lfsr[8][48:1];
   assign b35 = lfsr[8][47:0];
   assign b36 = lfsr[9][50:3];
   assign b37 = lfsr[9][49:2];

   // Note that lfsr[47:0] is represented on next LFSR[n+1] compute
   always @(posedge CLK)
     begin
        match0 <= {        `Compute (b0), `Compute (b1), `Compute (b2), `Compute (b3)};
        match1 <= {match0, `Compute (b4), `Compute (b5), `Compute (b6), `Compute (b7)};
        match2 <= {match1, `Compute (b8), `Compute (b9), `Compute (b10),`Compute (b11)};
        match3 <= {match2, `Compute (b12),`Compute (b13),`Compute (b14),`Compute (b15)};
        match4 <= {match3, `Compute (b16),`Compute (b17),`Compute (b18),`Compute (b19)};
        match5 <= {match4, `Compute (b20),`Compute (b21),`Compute (b22),`Compute (b23)};
        match6 <= {match5, `Compute (b24),`Compute (b25),`Compute (b26),`Compute (b27)};
        match7 <= {match6, `Compute (b28),`Compute (b29),`Compute (b30),`Compute (b31)};
        match8 <= {match7, `Compute (b32),`Compute (b33),`Compute (b34),`Compute (b35)};
        match9 <= {match8, `Compute (b36),`Compute (b37)};
     end // always @ (posedge CLK)
                      
   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= WAIT_FULL;
             ring_valid <= 0;
             ring_rden <= 0;
             valid <= 0;
             DONE <= 0;
             KEY_VALID <= 0;
          end
        else
          begin

             // Save key
             key_save <= lfsr[9][51:4];
             
             // Check key
             if (valid[10] && (match9 == BITSTREAM[37:0]))
               begin
                  KEY_VALID <= 1;
                  state <= FINISHED;
                  key <= key_save;
               end
                         
             // Generate 48 bits of LFSR from even/odd subkeys
             // Plus 4 bits of extended bitstream
             lfsr[0][51:0] <= {even_subkey[23], odd_subkey[23], even_subkey[22], odd_subkey[22], // 47-44
                               even_subkey[21], odd_subkey[21], even_subkey[20], odd_subkey[20], // 43-40
                               even_subkey[19], odd_subkey[19], even_subkey[18], odd_subkey[18], // 39-36
                               even_subkey[17], odd_subkey[17], even_subkey[16], odd_subkey[16], // 35-32
                               even_subkey[15], odd_subkey[15], even_subkey[14], odd_subkey[14], // 31-28
                               even_subkey[13], odd_subkey[13], even_subkey[12], odd_subkey[12], // 27-24
                               even_subkey[11], odd_subkey[11], even_subkey[10], odd_subkey[10], // 23-20
                               even_subkey[9],  odd_subkey[9],  even_subkey[8],  odd_subkey[8],  // 19-16
                               even_subkey[7],  odd_subkey[7],  even_subkey[6],  odd_subkey[6],  // 15-12
                               even_subkey[5],  odd_subkey[5],  even_subkey[4],  odd_subkey[4],  // 11-8
                               even_subkey[3],  odd_subkey[3],  even_subkey[2],  odd_subkey[2],  // 7-4
                               even_subkey[1],  odd_subkey[1],  even_subkey[0],  odd_subkey[0],  // 3-0
                               // Generated bit 3
                               (even_subkey[23] ^ odd_subkey[21] ^ odd_subkey[19] ^ even_subkey[18] ^
                                even_subkey[17] ^ even_subkey[16] ^ odd_subkey[16] ^ odd_subkey[15] ^
                                odd_subkey[14] ^ even_subkey[11] ^ odd_subkey[11] ^ odd_subkey[10] ^
                                odd_subkey[9] ^ odd_subkey[6] ^ odd_subkey[4] ^ odd_subkey[3] ^
                                even_subkey[2] ^  odd_subkey[2]),
                               // Generated bit 2
                               (odd_subkey[23] ^ even_subkey[20] ^ even_subkey[18] ^ odd_subkey[18] ^
                                odd_subkey[17] ^ odd_subkey[16] ^ even_subkey[15] ^ even_subkey[14] ^
                                even_subkey[13] ^ odd_subkey[11] ^ even_subkey[10] ^ even_subkey[9] ^
                                even_subkey[8] ^ even_subkey[5] ^ even_subkey[3] ^ even_subkey[2] ^
                                odd_subkey[2] ^ even_subkey[1]),
                               // Generated bit 1
                               (even_subkey[22] ^ odd_subkey[20] ^ odd_subkey[18] ^ even_subkey[17] ^
                                even_subkey[16] ^ even_subkey[15] ^ odd_subkey[15] ^ odd_subkey[14] ^
                                odd_subkey[13] ^ even_subkey[10] ^ odd_subkey[10] ^ odd_subkey[9] ^
                                odd_subkey[8] ^ odd_subkey[5] ^ odd_subkey[3] ^ odd_subkey[2] ^
                                even_subkey[1] ^  odd_subkey[1]),
                               // Generated bit 0
                               (odd_subkey[22] ^ even_subkey[19] ^ even_subkey[17] ^ odd_subkey[17] ^
                                odd_subkey[16] ^ odd_subkey[15] ^ even_subkey[14] ^ even_subkey[13] ^
                                even_subkey[12] ^ odd_subkey[10] ^ even_subkey[9] ^ even_subkey[8] ^
                                even_subkey[7] ^ even_subkey[4] ^ even_subkey[2] ^ even_subkey[1] ^
                                odd_subkey[1] ^ even_subkey[0])
                               };
             
             // Even data valid next cycle
             if (ring_rden)
               ring_valid <= 1;
             else
               ring_valid <= 0;

             // Mark pipeline spot as valid/invalid
             if (ring_valid)
               valid <= {valid[9:0], 1'b1};
             else
               valid <= {valid[9:0], 1'b0};
             
             case (state)
               
               // Wait until both ring buffers full
               WAIT_FULL:
                 begin
                    // Release ring from reset
                    ring_reset_n <= 1;

                    // Release odd generator from reset
                    odd_reset_n <= 1;
                    
                    // Wait until ring buffer is full
                    if (ring_full & ring_reset_n & ~ofifo_rdempty)
                      begin
                         state <= COMPARE;
                         // Read subkey from odd generator
                         ofifo_rden <= 1;
                         // Read subkey from ring buffer
                         ring_rden <= 1;
                      end
                 end

               // Iterate all odd combinations for each even in ring buffer
               COMPARE:
                 begin

                    // Cycle odd keys for every complete ring buffer
                    if (ofifo_rden)
                      ofifo_rden <= 0;
                    else if (ring_end & ~odd_done & ~ofifo_rdempty)
                      ofifo_rden <= 1;

                    // Have we exhausted search space?
                    if (even_done & ring_end)
                      begin
                         state <= WAIT_FINISH;
                         ring_rden <= 0;
                      end
                    
                    // Done with current ring buffer
                    else if (odd_done & ring_end)
                      begin
                         // Fetch next ring buffer
                         odd_reset_n <= 0;
                         ring_reset_n <= 0;
                         state <= WAIT_FULL;
                         ring_rden <= 0;
                      end

                 end // case: COMPARE

               
               // Wait til pipeline is empty
               WAIT_FINISH:
                 if (~|valid)
                   state <= FINISHED;
               
               // Finished searching - Either found key
               // or exhausted search space
               FINISHED:
                 begin
                    DONE <= 1;
                    if (KEY_VALID)
                      begin
                         if (KEY_CLK)
                           begin
                              KEY_DATA <= key[47];
                              key <= {key[46:0], 1'b0};
                           end
                      end
                 end
             endcase // case (state)

          end // else: !if(~RESETn)
        
     end // always @ (posedge CLK)
   
endmodule // Crypto1Core
