//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_controller_wb.v                                           ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// Wishbone interface responsible for comunication with core    ////
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

module sd_controller_wb(
           clk,
           rst,
           sd_clk,

           we, 
           addr,
           data_in,
           data_out,

           cmd_start,
           data_int_rst,
           cmd_int_rst,
           argument_reg,
           command_reg,
           response_0_reg,
           response_1_reg,
           response_2_reg,
           response_3_reg,
           software_reset_reg,
           cmd_timeout_reg,
           data_timeout_reg,
           block_size_reg,
           controll_setting_reg,
           cmd_int_status_reg,
           clock_divider_reg,
           block_count_reg,
           data_int_status_reg,
       );

input wire clk;
input wire rst;
input wire sd_clk;

input wire we;
input wire [6:0] addr;
input wire [7:0] data_in;
output logic [7:0] data_out;

output reg cmd_start;

//Buss accessible registers
output [31:0] argument_reg;
output [`CMD_REG_SIZE-1:0] command_reg;
input wire [31:0] response_0_reg;
input wire [31:0] response_1_reg;
input wire [31:0] response_2_reg;
input wire [31:0] response_3_reg;
output [0:0] software_reset_reg;
output [`CMD_TIMEOUT_W-1:0] cmd_timeout_reg;
output [`DATA_TIMEOUT_W-1:0] data_timeout_reg;
output [`BLKSIZE_W-1:0] block_size_reg;
output [0:0] controll_setting_reg;
input wire [`INT_CMD_SIZE-1:0] cmd_int_status_reg;
output [7:0] clock_divider_reg;
input  wire [`INT_DATA_SIZE-1:0] data_int_status_reg;
//Register Controll
output reg data_int_rst;
output reg cmd_int_rst;
output [`BLKCNT_W-1:0]block_count_reg;

parameter voltage_controll_reg  = `SUPPLY_VOLTAGE_mV;
parameter capabilies_reg = 16'b0000_0000_0000_0000;

wire [6:0] reg_addr = {addr[6:2], 2'b00};
wire [1:0] byte_sel = addr[1:0];

byte_en_reg #(32) argument_r(clk, rst, we && reg_addr == `argument, byte_sel, data_in, argument_reg);
byte_en_reg #(`CMD_REG_SIZE) command_r(clk, rst, we && reg_addr == `command, byte_sel, data_in, command_reg);
byte_en_reg #(8) reset_r(clk, rst, we && reg_addr == `reset, byte_sel, data_in, software_reset_reg); //TODO: find a way to make this 1 bit
byte_en_reg #(`CMD_TIMEOUT_W) cmd_timeout_r(clk, rst, we && reg_addr == `cmd_timeout, byte_sel, data_in, cmd_timeout_reg);
byte_en_reg #(`DATA_TIMEOUT_W) data_timeout_r(clk, rst, we && reg_addr == `data_timeout, byte_sel, data_in, data_timeout_reg);
byte_en_reg #(`BLKSIZE_W, `RESET_BLOCK_SIZE) block_size_r(clk, rst, we && reg_addr == `blksize, byte_sel, data_in, block_size_reg);
byte_en_reg #(8, 0) controll_r(clk, rst, we && reg_addr == `controller, byte_sel, data_in, controll_setting_reg); //TODO: find a way to make this 1 bit
byte_en_reg #(8, 1) clock_d_r(clk, rst, we && reg_addr == `clock_d, byte_sel, data_in, clock_divider_reg);
byte_en_reg #(`BLKCNT_W) block_count_r(clk, rst, we && reg_addr == `blkcnt, byte_sel, data_in, block_count_reg);
//*

// These registers take the cmd_start signal (and other signals) from the system clock speed domain 
// and transfers it to the SD card clock speed domain.
// This assumes that a clock divider is used to generate the SD card clock - 
// no proper clock domain crossing is done.
reg prev_clk;
always @(posedge clk)
begin
    if (rst)begin
        cmd_start <= 0;
        data_int_rst <= 0;
        cmd_int_rst <= 0;
        prev_clk <= 0;
    end else begin
        prev_clk <= sd_clk;

        if (prev_clk == 0 && sd_clk == 1)begin
            cmd_start <= 0;
            if (data_int_rst) data_int_rst <= 0;
            cmd_int_rst <= 0;
        end 
        if (we && byte_sel == 2'b00) begin
            case (reg_addr)
                `argument: cmd_start <= 1;
                `cmd_isr: cmd_int_rst <= 1;
                `data_isr: data_int_rst <= 1;
            endcase
        end
    end
end//*/



// TODO: Some of these registers don't need to be read from. They should be removed from the case statement to save LUTs.
logic [31:0] wb_dat_o;
always_comb begin
	wb_dat_o = 32'd0;
    case (reg_addr)
        `argument: wb_dat_o = argument_reg;
        `command: wb_dat_o[`CMD_REG_SIZE-1:0] = command_reg;
        `resp0: wb_dat_o = response_0_reg;
        `resp1: wb_dat_o = response_1_reg;
        `resp2: wb_dat_o = response_2_reg;
        `resp3: wb_dat_o = response_3_reg;
        `controller: wb_dat_o[0] = controll_setting_reg;
        `blksize: wb_dat_o[`BLKSIZE_W-1:0] = block_size_reg;
        `voltage: wb_dat_o = voltage_controll_reg;
        `reset: wb_dat_o[0] = software_reset_reg;
        `cmd_timeout: wb_dat_o[`CMD_TIMEOUT_W-1:0] = cmd_timeout_reg;
        `data_timeout: wb_dat_o[`DATA_TIMEOUT_W-1:0] = data_timeout_reg;
        `cmd_isr: wb_dat_o[`INT_CMD_SIZE-1:0] = cmd_int_status_reg;
        `clock_d: wb_dat_o[7:0] = clock_divider_reg;
        `capa: wb_dat_o[15:0] = capabilies_reg;
        `data_isr: wb_dat_o[`INT_DATA_SIZE-1:0] = data_int_status_reg;
        `blkcnt: wb_dat_o[`BLKCNT_W-1:0] = block_count_reg;
    endcase
    case (byte_sel)
        2'b00: data_out = wb_dat_o[7:0];
        2'b01: data_out = wb_dat_o[15:8];
        2'b10: data_out = wb_dat_o[23:16];
        2'b11: data_out = wb_dat_o[31:24];
    endcase
end
//*/
endmodule
