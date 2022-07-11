/**
 *
 * Top-level RTL to instantiate an attack on
 * the Crypto1 stream cipher.
 * At a high-level we do the following:
 * - Instantiate 256 identical cores
 * - Each core takes an two indices (0,15) which represent
 *   a portion of the search spaces for the first two
 *   even/odd bits. 256 cores cover the entire search space.
 * - Each core will perform 4 extensions per even/odd and
 *   combine them thus creating a 48 bit potential key.
 * - An XOR check is performed on the combined key to filter
 *   out half the results.
 * - The resulting 48 bit potential key then gets extended
 *   to 86 bits using the normal LFSR feeback.
 * - The remaining 38 output bits are calculated from the
 *   the full 86bit extended LFSR.
 * - The verify bits [:10+] are then checked against these
 *   output bits to see if the key was found.
 * - Matches are then latched onto a shared bus for final
 *   check against the remaining output stream.
 * - 48 bit known output stream required to generate a single
 *   valid key.
 * - The resulting key found will be 45 cycles into the LFSR.
 *   It can then be rewound 45 cycles using simple XOR rotation.
 * 
 *   This attack follows the algorithm cited in: [CITATION]
 * 
 * Elliot Buller
 * 2022
 * This work is my own and does not represent the entity/entities
 * that I may represent.
 */

/**
 * # Test data
 * # key=0x27568d75631f
 * # key_found=ee3de5499562 (45 cycles past SR[0])
 * # output=0x5a7be10a7259ef48
 */ 
module Crypto1Attack
  (
   input               CLK,
   input               RESETn,
   input [47:0]        BITSTREAM,
   output logic [47:0] KEY,
   output logic        VALID,
   output logic        DONE
   );

   logic [255:0]       valid, data, done;
   logic               key_data, key_clk, all_done;
   logic [7:0]         select;
   logic [6:0]         ctr;
   
   // Instantiate 256 cores containing all combinations
   // of indices i,j
   genvar              i, j;
   generate
//      for (i = 0; i < 16; i++) begin
//         for (j = 0; j < 16; j++) 
      for (i = 5; i < 6; i++) begin
         for (j = 0; j < 1; j++) 
           begin : Crypto1Core
            Crypto1Core #(.EIDX(i), .OIDX(j), .RING_DEPTH(32))
              core
                  (
                   .CLK       (CLK),
                   .RESETn    (RESETn),
                   .BITSTREAM (BITSTREAM),
                   .KEY_CLK   (key_clk),
                   .KEY_DATA  (data[(i << 4) | j]),
                   .KEY_VALID (valid[(i << 4) | j]),
                   .DONE      (done[(i << 4) | j])
                   );
           end
      end
   endgenerate

   // MUX one-hot outputs
   genvar              k;
   generate for (k = 0; k < 256; k++)
     begin : GEN_MUX
        always @(posedge CLK)
          if (valid == 2**k)
            select <= 8'(k);
     end
   endgenerate

   // Finished when one core finds key or 
   // all have finished searching
   always all_done = |valid | &done;
   
   // Select corresponding key data
   always key_data = data[select];

   always @(posedge CLK)
     if (~RESETn)
       begin
          DONE <= 0;
          VALID <= 0;
          key_clk <= 0;
          ctr <= 0;
       end
     else
       begin
          // Found key
          if (|valid)
            begin
               // Set key as valid
               VALID <= 1;

               // Clock in key data
               if (ctr < 98)
                 begin
                    ctr <= ctr + 1;
                    key_clk <= ~key_clk;
                    if (~ctr[0])
                      KEY <= {KEY[46:0], key_data};
                 end
               else
                 // Mark as done
                 DONE <= 1;
            end

          // Key not found
          else if (&done)
            DONE <= 1;
       end

endmodule // Crypto1Attack

                     
