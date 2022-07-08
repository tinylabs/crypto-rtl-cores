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
       // Clock out data using serial stream
       // when complete
       output logic KEY_DATA,
       //input        KEY_CLK,
       output logic KEY_VALID
   );

`include "crypto1.vh"
   
   // State machine
   typedef enum            logic [2:0] {
                                        WAIT_FULL = 0,
                                        COMPARE   = 1,
                                        FINISHED  = 2
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
           .BITSTREAM      (5'b01100), // Forward = 00110
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

   // Odd subkey generator
   GenSubkey #( .IDX (OIDX) )
   u_odd (
           .CLK            (CLK),
           .RESETn         (RESETn & odd_reset_n),
           .BITSTREAM      (5'b10011), // Forward = 11001
           .SUBKEY_RDEN    (ofifo_rden),
           .SUBKEY_RDDATA  (odd_subkey),
           .SUBKEY_RDEMPTY (ofifo_rdempty),
           .DONE           (odd_done)
           );

   // Generate 48 bit key from even/odd subkeys
   logic [47:0]            key;
   always key = {even_subkey[23], odd_subkey[23], even_subkey[22], odd_subkey[22],
                 even_subkey[21], odd_subkey[21], even_subkey[20], odd_subkey[20],
                 even_subkey[19], odd_subkey[19], even_subkey[18], odd_subkey[18],
                 even_subkey[17], odd_subkey[17], even_subkey[16], odd_subkey[16],
                 even_subkey[15], odd_subkey[15], even_subkey[14], odd_subkey[14],
                 even_subkey[13], odd_subkey[13], even_subkey[12], odd_subkey[12],
                 even_subkey[11], odd_subkey[11], even_subkey[10], odd_subkey[10],
                 even_subkey[9],  odd_subkey[9],  even_subkey[8],  odd_subkey[8],
                 even_subkey[7],  odd_subkey[7],  even_subkey[6],  odd_subkey[6],
                 even_subkey[5],  odd_subkey[5],  even_subkey[4],  odd_subkey[4],
                 even_subkey[3],  odd_subkey[3],  even_subkey[2],  odd_subkey[2],
                 even_subkey[1],  odd_subkey[1],  even_subkey[0],  odd_subkey[0]};

   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             state <= WAIT_FULL;
             ring_valid <= 0;
          end
        else
          begin

             // Even data valid next cycle
             if (ring_rden)
               ring_valid <= 1;
             else
               ring_valid <= 0;
             
             case (state)
               default:
                 state <= WAIT_FULL;
               
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

                    if (even_done & ring_end)
                      begin
                         state <= FINISHED;
                      end

                    // Done with current ring buffer
                    else if (odd_done & ring_end)
                      begin
                         odd_reset_n <= 0;
                         ring_reset_n <= 0;
                         state <= WAIT_FULL;
                         ring_rden <= 0;
                      end

                    // Both subkeys valid
                    else if (ring_valid)
                      begin

                         // Check XOR
                         if (`XOR_OK (key))
                           $display ("key=%012x", key);

                         // Debug
                         if (key == 48'had1aeac63ee3)
                           $finish;
                             
                         // Iterate next even key
                         ring_rden <= 1;

                      end // else: !if(ring_end)
                    
                                                                      
                 end // case: COMPARE

               // Finished searching - Either found key
               // or exhausted search space
               FINISHED:
                 begin
                    $finish;
                 end
             endcase // case (state)
             
          end
     end
endmodule // Crypto1Core
