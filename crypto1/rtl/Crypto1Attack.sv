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
 * - The resulting key found will be 10 cycles into the LFSR.
 *   It can then be rewound 10 cycles using simple XOR rotation.
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
 * # output=0x5a7be10a7259ef48
 */ 
module Crypto1Attack
  (
   input               CLK,
   input               RESETn,
   input [47:0]        BITSTREAM,
   output logic [47:0] KEY
   );

   // Instantiate 256 cores containing all combinations
   // of indices i,j
   /*
   genvar              i, j;
   generate
      for (i = 0; i < 16; i++) begin
         for (j = 0; j < 16; j++) 
           begin : Crypto1Core
            Crypto1Core core
                  (
                   .CLK       (CLK),
                   .RESETn    (RESETn),
                   .EIDX      (i),
                   .OIDX      (j),
                   .BITSTREAM ({<<{BITSTREAM}}),
                   .KEY       (KEY)
                   );
              
         end
      end
   endgenerate
    */
   logic               done, key_data, key_valid;
   
   
   Crypto1Core #(
                 .EIDX (5),
                 .OIDX (0),
                 .RING_DEPTH (32))
   u_core
     (
      .CLK       (CLK),
      .RESETn    (RESETn),
      .BITSTREAM ({<<{48'h5a7be10a7259}}), // Reversed keystream
      .KEY_DATA  (key_data),
      .KEY_VALID (key_valid),
      .DONE      (done)
      );
      
endmodule // Crypto1Attack

                     
