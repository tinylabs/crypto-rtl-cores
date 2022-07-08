/**
 *
 * Ring buffer - Takes FIFO signals in. Fills up ring buffer.
 * Client can cycle through entries until complete.
 * 
 * Elliot Buller
 * 2022
 */

module RingBuf 
  #(
    parameter DEPTH,
    parameter WIDTH
  ) (
     input              CLK,
     input              RESETn,

     // Input FIFO
     input [WIDTH-1:0]  FIFO_RDDATA,
     output logic       FIFO_RDEN,
     input              FIFO_RDEMPTY,
     input              FIFO_DONE,
     // Client interface
     input              RDEN,
     output logic [WIDTH-1:0] RDDATA,
     output logic       FULL,
     // No more data
     output logic       DONE,
     // End of current ring buffer
     output logic       END);

   // Create internal buffer of width/depth
   logic [WIDTH-1:0]         data [DEPTH];
   logic [$clog2(DEPTH):0]   widx;
   logic [$clog2(DEPTH):0]   ridx;
   logic                     data_valid;
   
   // Read while data is available and not full
   always FIFO_RDEN = ~FIFO_RDEMPTY & (widx < DEPTH - 1);
   always FULL = (widx == DEPTH);
   always END = (ridx == (widx - 1));
   always DONE = (FIFO_DONE & END);
                
   always @(posedge CLK)
     begin
        if (~RESETn)
          begin
             ridx <= 0;
             widx <= 0;
             data_valid <= 0;
          end
        else
          begin
             // Latch data next cycle
             if (FIFO_RDEN)
               data_valid <= 1;
             else
               data_valid <= 0;

             // Write data into ring buffer
             if (data_valid)
               begin
                  data[widx[$clog2(DEPTH)-1:0]] <= FIFO_RDDATA;
                  widx <= widx + 1;
               end

             // If RDEN push data out and increment
             if (RDEN)
               begin
                  RDDATA <= data[ridx[$clog2(DEPTH)-1:0]];
                  ridx <= ridx + 1;
               end
          end
     end
endmodule // RingBuf

