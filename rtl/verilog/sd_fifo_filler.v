//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_fifo_filler.v                                             ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// Fifo interface between sd card and wishbone clock domains    ////
//// and DMA engine eble to write/read to/from CPU memory         ////
////                                                              ////
//// Author(s):                                                   ////
////     - Marek Czerski, ma.czerski@gmail.com                    ////
////                                                              ////
//////////////////////////////////////////////////////////////////////
////                                                              ////
//// Copyright (C) 2013 Authors                                   ////
////                                                              ////
//// Based on original work by                                    ////
////     Adam Edvardsson (adam.edvardsson@orsoc.se)               ////
////                                                              ////
////     Copyright (C) 2009 Authors                               ////
////                                                              ////
//// This source file may be used and distributed without         ////
//// restriction provided that this copyright statement is not    ////
//// removed from the file and that any derivative work contains  ////
//// the original copyright notice and the associated disclaimer. ////
////                                                              ////
//// This source file is free software; you can redistribute it   ////
//// and/or modify it under the terms of the GNU Lesser General   ////
//// Public License as published by the Free Software Foundation; ////
//// either version 2.1 of the License, or (at your option) any   ////
//// later version.                                               ////
////                                                              ////
//// This source is distributed in the hope that it will be       ////
//// useful, but WITHOUT ANY WARRANTY; without even the implied   ////
//// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR      ////
//// PURPOSE. See the GNU Lesser General Public License for more  ////
//// details.                                                     ////
////                                                              ////
//// You should have received a copy of the GNU Lesser General    ////
//// Public License along with this source; if not, download it   ////
//// from http://www.opencores.org/lgpl.shtml                     ////
////                                                              ////
//////////////////////////////////////////////////////////////////////

module sd_fifo_filler(
           input clk,
           input rst,

           output [7:0] rd_dat_o,
           input rd_en_i,

           //Data Serial signals
           input sd_clk,
           input [7:0] dat_i,
           output [7:0] dat_o,
           input wr_i,
           input rd_i,
           output sd_full_o,
           output sd_empty_o,
           output wb_full_o,
           output wb_empty_o
       );

`define FIFO_MEM_ADR_SIZE 10
`define MEM_OFFSET 4

wire reset_fifo = 1'b0;
wire fifo_rd;
reg fifo_rd_ack;
reg fifo_rd_reg;

//assign fifo_rd = wbm_cyc_o & wbm_ack_i;
//assign reset_fifo = !en_rx_i & !en_tx_i;

//assign wbm_we_o = en_rx_i & !wb_empty_o;
//assign wbm_cyc_o = en_rx_i ? en_rx_i & !wb_empty_o : en_tx_i & !wb_full_o;
//assign wbm_stb_o = en_rx_i ? wbm_cyc_o & fifo_rd_ack : wbm_cyc_o;

generic_fifo_dc_gray #(
    .dw(8), 
    .aw(`FIFO_MEM_ADR_SIZE)
    ) generic_fifo_dc_gray0 (
    .rd_clk(clk),
    .wr_clk(sd_clk), 
    .rst(!(rst | reset_fifo)), 
    .clr(1'b0), 
    .din(dat_i), 
    .we(wr_i),
    .dout(rd_dat_o), 
    .re(rd_en_i),//en_rx_i & wbm_cyc_o & wbm_ack_i), 
    .full(sd_full_o), 
    .empty(wb_empty_o), 
    .wr_level(), 
    .rd_level() 
    );
    
generic_fifo_dc_gray #(
    .dw(8), 
    .aw(`FIFO_MEM_ADR_SIZE)
    ) generic_fifo_dc_gray1 (
    .rd_clk(sd_clk),
    .wr_clk(clk), 
    .rst(!(rst | reset_fifo)), 
    .clr(1'b0), 
    .din(wbm_dat_i), 
    .we(1'b0),//en_tx_i & wbm_cyc_o & wbm_stb_o & wbm_ack_i),
    .dout(dat_o), 
    .re(rd_i), 
    .full(wb_full_o), 
    .empty(sd_empty_o), 
    .wr_level(), 
    .rd_level() 
    );

/*
always @(posedge clk or posedge rst)
    if (rst) begin
        wbm_adr_o <= 0;
        fifo_rd_reg <= 0;
        fifo_rd_ack <= 1;
    end
    else begin
        fifo_rd_reg <= fifo_rd;
        fifo_rd_ack <= fifo_rd_reg | !fifo_rd;
        if (wbm_cyc_o & wbm_stb_o & wbm_ack_i)
            wbm_adr_o <= wbm_adr_o + `MEM_OFFSET;
        else if (reset_fifo)
            wbm_adr_o <= adr_i;
    end
*/
endmodule


