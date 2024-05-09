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

           input [7:0] wr_dat_i,
           input wr_en_i,

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

//`define BENCHMARK
`define FIFO_MEM_ADR_SIZE 10
`define MEM_OFFSET 4

wire fifo_rd;
reg fifo_rd_ack;
reg fifo_rd_reg;

`define VIVADO
//`define RADIANT

//assign fifo_rd = wbm_cyc_o & wbm_ack_i;
//assign reset_fifo = !en_rx_i & !en_tx_i;

//assign wbm_we_o = en_rx_i & !wb_empty_o;
//assign wbm_cyc_o = en_rx_i ? en_rx_i & !wb_empty_o : en_tx_i & !wb_full_o;
//assign wbm_stb_o = en_rx_i ? wbm_cyc_o & fifo_rd_ack : wbm_cyc_o;

/*
module monostable_domain_cross(
    input rst,
    input clk_a,
    input in, 
    input clk_b,
    output out
);*/
`ifdef VIVADO
    wire rd_en_i_cross, wr_en_i_cross;
    monostable_domain_cross rd_en_cross(
        .rst(rst), .clk_a(clk), .in(rd_en_i), .clk_b(sd_clk), .out(rd_en_i_cross)
    );
    monostable_domain_cross wr_en_cross(
        .rst(rst), .clk_a(clk), .in(wr_en_i), .clk_b(sd_clk), .out(wr_en_i_cross)
    );

    fifo_generator_0 rd_fifo(
        .clk(sd_clk), 
        .rst(rst), 
        .din(dat_i), 
        .wr_en(wr_i),
        .dout(rd_dat_o), 
        .rd_en(rd_en_i_cross),
        //.full(sd_full_o), 
        .empty(wb_empty_o)
    );
    assign sd_full_o = 1'b0;
    fifo_generator_0 wr_fifo(
        .clk(sd_clk), 
        .rst(rst), 
        .din(wr_dat_i), 
        .wr_en(wr_en_i_cross),
        .dout(dat_o), 
        .rd_en(rd_i), 
        .full(wb_full_o) 
        //.empty(sd_empty_o)
    );
    assign sd_empty_o = 1'b0;
`elsif RADIANT
    sd_fifo rd_fifo(
        .rd_clk_i(clk),
        .wr_clk_i(sd_clk), 
        .rst_i(rst), 
        .wr_data_i(dat_i), 
        .wr_en_i(wr_i),
        .rd_data_o(rd_dat_o), 
        .rd_en_i(rd_en_i),
        .full_o(sd_full_o), 
        .empty_o(wb_empty_o)
    );
    sd_fifo wr_fifo(
        .rd_clk_i(sd_clk),
        .wr_clk_i(clk), 
        .rst_i(rst), 
        .wr_data_i(wr_dat_i), 
        .wr_en_i(wr_en_i),
        .rd_data_o(dat_o), 
        .rd_en_i(rd_i), 
        .full_o(wb_full_o), 
        .empty_o(sd_empty_o)
    );
`else

    wire rd_en_i_cross, wr_en_i_cross;
    monostable_domain_cross rd_en_cross(
        .rst(rst), .clk_a(clk), .in(rd_en_i), .clk_b(sd_clk), .out(rd_en_i_cross)
    );
    monostable_domain_cross wr_en_cross(
        .rst(rst), .clk_a(clk), .in(wr_en_i), .clk_b(sd_clk), .out(wr_en_i_cross)
    );

    generic_fifo_sc_a #(
        .dw(8), 
        .aw(`FIFO_MEM_ADR_SIZE)
        ) generic_fifo_dc_gray0 (
        .clk(sd_clk), 
        .rst(!rst), 
        .din(dat_i), 
        .we(wr_i),
        .dout(rd_dat_o), 
        .re(rd_en_i_cross),
        //.full(sd_full_o), 
        .empty(wb_empty_o), 
        .level(), 

        `ifdef BENCHMARK 
            .clr(1'b1)
        `else
            .clr(1'b0)
        `endif
    );
    assign sd_full_o = 1'b0;
    generic_fifo_sc_a #(
        .dw(8), 
        .aw(`FIFO_MEM_ADR_SIZE)
        ) generic_fifo_dc_gray1 (
        .clk(sd_clk),
        .rst(!rst), 
        .clr(1'b0), 
        .din(wr_dat_i), 
        .we(wr_en_i_cross),
        .dout(dat_o), 
        .re(rd_i), 
        .full(wb_full_o), 
        //.empty(sd_empty_o), 
        .level() 
    );
    assign sd_empty_o = 1'b0;
`endif

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


