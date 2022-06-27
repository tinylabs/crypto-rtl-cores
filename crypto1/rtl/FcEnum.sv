/**
 *  Non-linear function Fc enumerator
 *  NLF takes 5 inputs and produces a single output.
 *  fn=0xEC57E80A
 *  This enumerator reverses that and takes a single
 *  input bit to enumerator all states that produce
 *  that bit.
 * 
 *  Elliot Buller
 *  2022
 */

module FcEnum
  (
   input              CLK,
   input              RESETn,
   input              BIT,
   output logic [4:0] OUTPUT
   );

   logic [3:0]        ctr;

   /*
   // NLC(0)=[0, 2, 4, 5, 6, 7, 8, 9, 10, 12, 19, 21, 23, 24, 25, 28]
   logic [4:0] zero [16] =
               '{
                 5'd0, 5'd2, 5'd4, 5'd5,
                 5'd6, 5'd7, 5'd8, 5'd9,
                 5'd10, 5'd12, 5'd19, 5'd21,
                 5'd23, 5'd24, 5'd25, 5'd28 
                 };
   
   // NLC(1)=[1, 3, 11, 13, 14, 15, 16, 17, 18, 20, 22, 26, 27, 29, 30, 31]
   logic [4:0] one [16] =
               '{
                 5'd1, 5'd3, 5'd11, 5'd13,
                 5'd14, 5'd15, 5'd16, 5'd17,
                 5'd18, 5'd20, 5'd22, 5'd26,
                 5'd27, 5'd29, 5'd30, 5'd31 
                 };
   */
   logic [4:0] Fc[2][16] = '{
                             '{
                               5'd0, 5'd2, 5'd4, 5'd5,
                               5'd6, 5'd7, 5'd8, 5'd9,
                               5'd10, 5'd12, 5'd19, 5'd21,
                               5'd23, 5'd24, 5'd25, 5'd28 
                               },
                             '{
                               5'd1, 5'd3, 5'd11, 5'd13,
                               5'd14, 5'd15, 5'd16, 5'd17,
                               5'd18, 5'd20, 5'd22, 5'd26,
                               5'd27, 5'd29, 5'd30, 5'd31 
                               }
                             };
   
               
   always @(posedge CLK)
     begin
        if (~RESETn)
            ctr <= 0;
        else
            ctr <= ctr + 1;
        OUTPUT <= Fc[BIT][ctr];
        /*
        if (BIT)
            OUTPUT <= one[ctr];
        else
            OUTPUT <= zero[ctr];
         */
     end
   
endmodule // FcEnum
