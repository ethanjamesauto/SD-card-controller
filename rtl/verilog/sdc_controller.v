//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sdc_controller.v                                             ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// Top level entity.                                            ////
//// This core is based on the "sd card controller" project from  ////
//// http://opencores.org/project,sdcard_mass_storage_controller  ////
//// but has been largely rewritten. A lot of effort has been     ////
//// made to make the core more generic and easily usable         ////
//// with OSs like Linux.                                         ////
//// - data transfer commands are not fixed                       ////
//// - data transfer block size is configurable                   ////
//// - multiple block transfer support                            ////
//// - R2 responses (136 bit) support                             ////
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
`include "sd_defines.h"

module sdc_controller(
           clk,
           rst,

           we,
           addr,
           data_in,
           data_out,

           //SD BUS
           sd_cmd, 
           //card_detect,
           sd_dat, 
           sd_clk_o_pad,
           int_cmd, 
           int_data,

           //FIFO interface
           rd_en_i,
           rd_dat_o,

           wr_en_i,
           wr_dat_i
       );

input wire clk;
input wire rst;

input wire we;
input wire [6:0] addr;
input wire [7:0] data_in;
output wire [7:0] data_out;

//input card_detect;
inout wire [3:0] sd_dat;
wire [3:0] sd_dat_dat_i;
wire [3:0] sd_dat_out_o;
wire sd_dat_oe_o;
assign sd_dat = sd_dat_oe_o ? sd_dat_out_o : 4'bz;
assign sd_dat_dat_i = sd_dat;

inout wire sd_cmd;
wire sd_cmd_dat_i;
wire sd_cmd_out_o;
wire sd_cmd_oe_o;
assign sd_cmd = sd_cmd_oe_o ? sd_cmd_out_o : 1'bz;
assign sd_cmd_dat_i = sd_cmd;

output sd_clk_o_pad;
output int_cmd, int_data;

input rd_en_i;
output [7:0] rd_dat_o;

input wr_en_i;
input [7:0] wr_dat_i;

//SD clock
wire sd_clk_o; //Sd_clk used in the system
wire [3:0] wr_wbm_sel;
wire [`BLKSIZE_W+`BLKCNT_W-1:0] xfersize;
wire [31:0] wbm_adr;

wire go_idle;
wire cmd_start_sd_clk;
wire cmd_start;
wire [1:0] cmd_setting;
wire cmd_start_tx;
wire [39:0] cmd;
wire [119:0] cmd_response;
wire cmd_crc_ok;
wire cmd_index_ok;
wire cmd_finish;

wire d_write;
wire d_read;
wire [7:0] data_in_rx_fifo;
wire [7:0] data_out_tx_fifo;
wire start_tx_fifo;
wire start_rx_fifo;
wire tx_fifo_empty;
wire tx_fifo_full;
wire rx_fifo_full;
wire sd_data_busy;
wire data_busy;
wire data_crc_ok;
wire rd_fifo;
wire we_fifo;

wire data_start_rx;
wire data_start_tx;
wire cmd_int_rst;
wire data_int_rst;


wire [31:0] argument_reg;
wire [`CMD_REG_SIZE-1:0] command_reg;
wire [`CMD_TIMEOUT_W-1:0] cmd_timeout_reg;
wire [`DATA_TIMEOUT_W-1:0] data_timeout_reg;
wire [0:0] software_reset_reg;
wire [31:0] response_0_reg;
wire [31:0] response_1_reg;
wire [31:0] response_2_reg;
wire [31:0] response_3_reg;
wire [`BLKSIZE_W-1:0] block_size_reg;
wire [0:0] controll_setting_reg;
wire [`INT_CMD_SIZE-1:0] cmd_int_status_reg;
wire [`INT_DATA_SIZE-1:0] data_int_status_reg;
wire [`BLKCNT_W-1:0] block_count_reg;
wire [1:0] dma_addr_reg;
wire [7:0] clock_divider_reg;

sd_clock_divider clock_divider0(
    .CLK (clk),
    .DIVIDER (clock_divider_reg),
    .RST  (rst),
    .SD_CLK  (sd_clk_o)
    );

assign sd_clk_o_pad  = sd_clk_o ;

sd_cmd_master sd_cmd_master0(
    .sd_clk       (sd_clk_o),
    .rst          (rst | software_reset_reg[0]),
    .start_i      (cmd_start),
    .int_status_rst_i(cmd_int_rst),
    .setting_o    (cmd_setting),
    .start_xfr_o  (cmd_start_tx),
    .go_idle_o    (go_idle),
    .cmd_o        (cmd),
    .response_i   (cmd_response),
    .crc_ok_i     (cmd_crc_ok),
    .index_ok_i   (cmd_index_ok),
    .busy_i       (sd_data_busy),
    .finish_i     (cmd_finish),
    .argument_i   (argument_reg),
    .command_i    (command_reg),
    .timeout_i    (cmd_timeout_reg),
    .int_status_o (cmd_int_status_reg),
    .response_0_o (response_0_reg),
    .response_1_o (response_1_reg),
    .response_2_o (response_2_reg),
    .response_3_o (response_3_reg)
    );

sd_cmd_serial_host cmd_serial_host0(
    .sd_clk     (sd_clk_o),
    .rst        (rst | 
                 software_reset_reg[0] | 
                 go_idle),
    .setting_i  (cmd_setting),
    .cmd_i      (cmd),
    .start_i    (cmd_start_tx),
    .finish_o   (cmd_finish),
    .response_o (cmd_response),
    .crc_ok_o   (cmd_crc_ok),
    .index_ok_o (cmd_index_ok),
    .cmd_dat_i  (sd_cmd_dat_i),
    .cmd_out_o  (sd_cmd_out_o),
    .cmd_oe_o   (sd_cmd_oe_o)
    );

sd_data_master sd_data_master0(
    .sd_clk           (sd_clk_o),
    .rst              (rst | 
                       software_reset_reg[0]),
    .start_tx_i       (data_start_tx),
    .start_rx_i       (data_start_rx),
    .timeout_i		  (data_timeout_reg),
    .d_write_o        (d_write),
    .d_read_o         (d_read),
    .start_tx_fifo_o  (start_tx_fifo),
    .start_rx_fifo_o  (start_rx_fifo),
    .tx_fifo_empty_i  (tx_fifo_empty),
    .tx_fifo_full_i   (tx_fifo_full),
    .rx_fifo_full_i   (rx_fifo_full),
    .xfr_complete_i   (!data_busy),
    .crc_ok_i         (data_crc_ok),
    .int_status_o     (data_int_status_reg),
    .int_status_rst_i (data_int_rst)
    );

sd_data_serial_host sd_data_serial_host0(
    .sd_clk         (sd_clk_o),
    .rst            (rst | software_reset_reg[0]),
    .data_in        (data_out_tx_fifo),
    .rd             (rd_fifo),
    .data_out       (data_in_rx_fifo),
    .we             (we_fifo),
    .DAT_oe_o       (sd_dat_oe_o),
    .DAT_dat_o      (sd_dat_out_o),
    .DAT_dat_i      (sd_dat_dat_i),
    .blksize        (block_size_reg),
    .bus_4bit       (controll_setting_reg[0]),
    .blkcnt         (block_count_reg),
    .start          ({d_read, d_write}),
    .byte_alignment (dma_addr_reg),
    .sd_data_busy   (sd_data_busy),
    .busy           (data_busy),
    .crc_ok         (data_crc_ok)
    );

sd_fifo_filler sd_fifo_filler0(
    .clk    (clk),
    .rst       (rst | software_reset_reg[0]),

    .rd_en_i   (rd_en_i),
    .rd_dat_o  (rd_dat_o),

    .wr_en_i   (wr_en_i),
    .wr_dat_i  (wr_dat_i),

    .sd_clk    (sd_clk_o),
    .dat_i     (data_in_rx_fifo),
    .dat_o     (data_out_tx_fifo),
    .wr_i      (we_fifo),
    .rd_i      (rd_fifo),
    .sd_empty_o   (tx_fifo_empty),
    .sd_full_o   (rx_fifo_full),
    .wb_empty_o   (),
    .wb_full_o    (tx_fifo_full)
    );


assign xfersize = (block_size_reg + 1'b1) * (block_count_reg + 1'b1);
sd_wb_sel_ctrl sd_wb_sel_ctrl0(
        .wb_clk         (clk),
        .rst            (rst | software_reset_reg[0]),
        .ena            (start_rx_fifo),
        .base_adr_i     (dma_addr_reg),
        .wbm_adr_i      (wbm_adr),
        .xfersize       (xfersize),
        .wbm_sel_o      (wr_wbm_sel)
        );

sd_data_xfer_trig sd_data_xfer_trig0 (
    .sd_clk                (sd_clk_o),
    .rst                   (rst | software_reset_reg[0]),
    .cmd_with_data_start_i (cmd_start & 
                            (command_reg[`CMD_WITH_DATA] != 
                             2'b00)),
    .r_w_i                 (command_reg[`CMD_WITH_DATA] == 
                            2'b01),
    .cmd_int_status_i      (cmd_int_status_reg),
    .start_tx_o            (data_start_tx),
    .start_rx_o            (data_start_rx)
    );

sd_controller_wb sd_controller_wb0(
    .clk                            (clk),
    .rst                            (rst),
    .sd_clk                         (sd_clk_o),

    .we                             (we),   
    .addr                           (addr),
    .data_in                        (data_in),
    .data_out                       (data_out),

    .cmd_start                      (cmd_start),
    .data_int_rst                   (data_int_rst),
    .cmd_int_rst                    (cmd_int_rst),
    .argument_reg                   (argument_reg),
    .command_reg                    (command_reg),
    .response_0_reg                 (response_0_reg),
    .response_1_reg                 (response_1_reg),
    .response_2_reg                 (response_2_reg),
    .response_3_reg                 (response_3_reg),
    .software_reset_reg             (software_reset_reg),
    .cmd_timeout_reg                (cmd_timeout_reg),
    .data_timeout_reg               (data_timeout_reg),
    .block_size_reg                 (block_size_reg),
    .controll_setting_reg           (controll_setting_reg),
    .cmd_int_status_reg             (cmd_int_status_reg),
    .clock_divider_reg              (clock_divider_reg),
    .block_count_reg                (block_count_reg),
    .data_int_status_reg            (data_int_status_reg)
    );

//sd_edge_detect cmd_start_edge(.rst(rst), .clk(clk), .sig(cmd_start), .rise(cmd_start), .fall());
//sd_edge_detect data_int_rst_edge(.rst(rst), .clk(clk), .sig(data_int_rst), .rise(data_int_rst), .fall());
//sd_edge_detect cmd_int_rst_edge(.rst(rst), .clk(clk), .sig(cmd_int_rst), .rise(cmd_int_rst), .fall());

//assign int_cmd =  |(clk & cmd_int_enable_reg);
//assign int_data =  |(clk & data_int_enable_reg);

endmodule
