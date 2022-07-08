/**
 *
 * Given an index for Fc, and an output bit,
 * Generate all 32768 20 bit combinations that
 * produce given output bit.
 * 
 * Elliot Buller
 * 2022
 */

module B20Enum
  #(
    parameter [3:0] IDX )
   (
    input               CLK,
    input               RESETn,
    input               BIT_IN,
    input               STB,
    output logic [19:0] KEY20,
    output logic        DONE
    );

   logic [14:0]        ctr;

   // NLF(a)=0x9E98 Note: these are bit reversed
   logic [3:0]         Fa [2][8] =
                       '{  // output=0
                         '{
                           4'd7, 4'd11, 4'd1, 4'd6,
                           4'd10, 4'd4, 4'd8, 4'd0
                           },
                         '{ // output=1
                            4'd15, 4'd3, 4'd13, 4'd5,
                            4'd9, 4'd14, 4'd2, 4'd12
                           }
                         };

   // NLF(b)=0xB48E Note: these are bit reversed
   logic [3:0]         Fb [2][8] =
                       '{  // output=0
                         '{
                           4'd7, 4'd13, 4'd9, 4'd1,
                           4'd6, 4'd10, 4'd2, 4'd0
                           },
                         '{ // output=1
                            4'd15, 4'd11, 4'd3, 4'd5,
                            4'd14, 4'd12, 4'd4, 4'd8
                           }
                         };
   

   // NLF(c)=0xEC57E80A
   logic [4:0]         Fc[2][16] = '{
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

   // Index decides Fc input
   logic [4:0]         sel;
   always sel = Fc[BIT_IN][IDX];

   // 15 bit counter arranged as 3 bit index for each function
   // Fb Fa Fa Fb Fa
   //logic [19:0]        k20;
   always KEY20 = {Fb[sel[0]][ctr[14:12]], 
                   Fa[sel[1]][ctr[11:9]],
                   Fa[sel[2]][ctr[8:6]],
                   Fb[sel[3]][ctr[5:3]],
                   Fa[sel[4]][ctr[2:0]]};
   
   logic               started;

   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             ctr <= 15'h7FFF;
             DONE <= 0;
             started <= 0;
          end
        else
          begin
             // Increment clock on strobe
             if (started && (ctr == 15'h7FFF))
               begin
                  DONE <= 1;
                  //$display ("%d: Enum: 0x%05X", ctr, KEY20);
               end
             else if (STB)
               begin
                  started <= 1;
                  ctr <= ctr + 1;
                  DONE <= 0;
                  //$display ("%d: Enum: 0x%05X", ctr, KEY20);
               end
          end
     end
endmodule // B20Enum
