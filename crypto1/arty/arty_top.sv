/**
 *  Digilent Arty A35-T top module
 * 
 *  Elliot Buller
 *  2022
 */

module arty_top
  (
   input CLK_100M,
   input RESETn,

   // UART to host
   input UART_RX,
   output UART_TX
   );

   // Clock generation
   logic  sysclk, transport_clk;
   logic  pll_locked, pll_feedback;
   
   // Assign expected values in generated code
   logic  CLK;
   assign CLK = sysclk;

   // Include generated AHB3lite interconnect crossbar
`include "ahb3lite_intercon.vh"

   // Include generated CSR regs
`include "crypto1_csr.vh"

   // ID value
   assign id = 32'hd00dcafe;
   
   // Dropped host comm bytes
   logic [9:0]          dropped;
   
   // Generate reset logic from pushbutton/pll
   logic [3:0]         reset_ctr;
   initial reset_ctr <= 'hf;

   always @(posedge sysclk)
     begin
        if (~RESETn | !pll_locked)
          reset_ctr <= 'hf;
        else if (reset_ctr)
          reset_ctr <= reset_ctr - 1;
     end
   assign poreset_n = (reset_ctr != 0) ? 1'b0 : 1'b1;

   // Generate sysclk/transport from 100M XTAL
   PLLE2_BASE #(
                .BANDWIDTH ("OPTIMIZED"),
                .CLKFBOUT_MULT (12),
                .CLKOUT0_DIVIDE(25),    // 48MHz transport
                .CLKOUT1_DIVIDE(10),    // 120MHz sysclk
                .CLKFBOUT_PHASE(0.0),   // Phase offset in degrees of CLKFB, (-360-360)
                .CLKIN1_PERIOD(10.0),   // 100MHz input clock
                .CLKOUT0_DUTY_CYCLE(0.5),
                .CLKOUT0_PHASE(0.0),
                .DIVCLK_DIVIDE(1),    // Master division value , (1-56)
                .REF_JITTER1(0.0),    // Reference input jitter in UI (0.000-0.999)
                .STARTUP_WAIT("FALSE") // Delay DONE until PLL Locks, ("TRUE"/"FALSE")
                ) u_pll (
                         // Clock outputs: 1-bit (each) output
                         .CLKOUT0(transport_clk),
                         .CLKOUT1(sysclk),
                         .CLKOUT2(),
                         .CLKOUT3(),
                         .CLKOUT4(),
                         .CLKOUT5(),
                         .CLKFBOUT(pll_feedback), // 1-bit output, feedback clock
                         .LOCKED(pll_locked),
                         .CLKIN1(CLK_100M),
                         .PWRDWN(1'b0),
                         .RST(1'b0),
                         .CLKFBIN(pll_feedback)    // 1-bit input, feedback clock
                         );
   
   // Master signals
   wire master_RDEN, master_WREN, master_WRFULL, master_RDEMPTY;
   wire [7:0] master_RDDATA, master_WRDATA;

   // Host AHB3 master
   assign ahb3_host_master_HSEL = 1'b1;
   assign ahb3_host_master_HMASTLOCK = 1'b0;

   // Loop back bitstream
   assign bitstream_hi_i = bitstream_hi_o;
   assign bitstream_lo_i = bitstream_lo_o;
   
   // Create crypto1 attack core
   Crypto1Attack
     u_attack (
               .CLK       (sysclk),
               .RESETn    (poreset_n & start),
               .BITSTREAM ({bitstream_hi_o, bitstream_lo_o}),
               .KEY       ({key_hi, key_lo}),
               .VALID     (valid),
               .DONE      (done)
               );
   
   // AHB3lite host
   ahb3lite_host_master
     u_host_master (
                    .CLK       (sysclk),
                    .RESETn    (poreset_n),
                    .HADDR     (ahb3_host_master_HADDR),
                    .HWDATA    (ahb3_host_master_HWDATA),
                    .HTRANS    (ahb3_host_master_HTRANS),
                    .HSIZE     (ahb3_host_master_HSIZE),
                    .HBURST    (ahb3_host_master_HBURST),
                    .HPROT     (ahb3_host_master_HPROT),
                    .HWRITE    (ahb3_host_master_HWRITE),
                    .HRDATA    (ahb3_host_master_HRDATA),
                    .HRESP     (ahb3_host_master_HRESP),
                    .HREADY    (ahb3_host_master_HREADY),
                    .RDEN      (master_RDEN),
                    .RDEMPTY   (master_RDEMPTY),
                    .RDDATA    (master_RDDATA),
                    .WREN      (master_WREN),
                    .WRFULL    (master_WRFULL),
                    .WRDATA    (master_WRDATA)
                    );

   // FIFO <=> Transport
   wire trans_RDEN, trans_WREN, trans_WRFULL, trans_RDEMPTY;
   wire [7:0] trans_RDDATA, trans_WRDATA;

   // CDC FIFOs
   dual_clock_fifo #(
                     .ADDR_WIDTH   (8),
                     .DATA_WIDTH   (8))
   u_tx_fifo (
              .wr_clk_i   (sysclk),
              .rd_clk_i   (transport_clk),
              .rd_rst_i   (~poreset_n),
              .wr_rst_i   (~poreset_n),
              .wr_en_i    (master_WREN),
              .wr_data_i  (master_WRDATA),
              .full_o     (master_WRFULL),
              .rd_en_i    (trans_RDEN),
              .rd_data_o  (trans_RDDATA),
              .empty_o    (trans_RDEMPTY)
              );
   dual_clock_fifo #(
                     .ADDR_WIDTH   (8),
                     .DATA_WIDTH   (8))
   u_rx_fifo (
              .rd_clk_i   (sysclk),
              .wr_clk_i   (transport_clk),
              .rd_rst_i   (~poreset_n),
              .wr_rst_i   (~poreset_n),
              .rd_en_i    (master_RDEN),
              .rd_data_o  (master_RDDATA),
              .empty_o    (master_RDEMPTY),
              .wr_en_i    (trans_WREN),
              .wr_data_i  (trans_WRDATA),
              .full_o     (trans_WRFULL)
              );

   // UART to host transport
   uart_fifo
     u_uart (
             .CLK        (transport_clk),
             .RESETn     (poreset_n),
             // UART interface
             .TX_PIN     (UART_TX),
             .RX_PIN     (UART_RX),
             // FIFO interface
             .FIFO_WREN  (trans_WREN),
             .FIFO_FULL  (trans_WRFULL),
             .FIFO_DOUT  (trans_WRDATA),
             .FIFO_RDEN  (trans_RDEN),
             .FIFO_EMPTY (trans_RDEMPTY),
             .FIFO_DIN   (trans_RDDATA),
             // Dropped bytes
             .DROPPED    (dropped)
             );

endmodule // arty_top

