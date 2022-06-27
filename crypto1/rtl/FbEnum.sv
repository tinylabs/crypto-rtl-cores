/**
 *  Non-linear function Fc enumerator
 *  NLF takes 4 inputs and produces a single output.
 *  fn=0xB48E
 *  This enumerator reverses that and takes a single
 *  input bit to enumerator all states that produce
 *  that bit.
 * 
 *  Elliot Buller
 *  2022
 */

module FbEnum
  (
   input              CLK,
   input              RESETn,
   input              BIT,
   output logic [3:0] OUTPUT
   );

   logic [2:0]        ctr;


   // NLB(0)=[0, 4, 5, 6, 8, 9, 11, 14]
   logic [3:0] zero [8] =
               '{
                 4'd0, 4'd4, 4'd5, 4'd6,
                 4'd8, 4'd9, 4'd11, 4'd14
                 };
   
   // NLB(1)=[1, 2, 3, 7, 10, 12, 13, 15]
   logic [3:0] one [8] =
               '{
                 4'd1, 4'd2, 4'd3, 4'd7,
                 4'd10, 4'd12, 4'd13, 4'd15
                 };
   
               
   always @(posedge CLK)
     begin
        if (~RESETn)
             ctr <= 0;
        else
             ctr <= ctr + 1;

        if (BIT)
             OUTPUT <= one[ctr];
        else
             OUTPUT <= zero[ctr];
     end
   
endmodule // FbEnum
