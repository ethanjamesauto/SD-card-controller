//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_cmd_master.v                                              ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// State machine resposible for controlling command transfers   ////
//// on 1-bit sd card command interface                           ////
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

module sd_cmd_master(
           input sd_clk,
           input rst,
           input start_i,
           input int_status_rst_i,
           output [1:0] setting_o,
           output reg start_xfr_o,
           output reg go_idle_o,
           output [39:0] cmd_o,
           input [119:0] response_i,
           input crc_ok_i,
           input index_ok_i,
           input finish_i,
           input busy_i, //direct signal from data sd data input (data[0])
           //input card_detect,
           input [31:0] argument_i,
           input [`CMD_REG_SIZE-1:0] command_i,
           input [`CMD_TIMEOUT_W-1:0] timeout_i,
           output [`INT_CMD_SIZE-1:0] int_status_o,
           output [31:0] response_0_o,
           output [31:0] response_1_o,
           output [31:0] response_2_o,
           output [31:0] response_3_o
       );

//-----------Types--------------------------------------------------------
reg crc_check;
reg index_check;
reg busy_check;
reg expect_response;
reg long_response;
reg [`INT_CMD_SIZE-1:0] int_status_reg;
//reg card_present;
//reg [3:0]debounce;
parameter SIZE = 2;
reg [SIZE-1:0] state;
parameter IDLE       = 2'b00;
parameter EXECUTE    = 2'b01;
parameter BUSY_CHECK = 2'b10;

assign setting_o[1:0] = {long_response, expect_response};
assign int_status_o = state == IDLE ? int_status_reg : 5'h0;

assign response_0_o = response_i[119:88];
assign response_1_o = response_i[87:56];
assign response_2_o = response_i[55:24];
assign response_3_o = {response_i[23:0], 8'h00};

//---------------Input ports---------------

// always @ (posedge sd_clk or posedge rst   )
// begin
//     if (rst) begin
//         debounce<=0;
//         card_present<=0;
//     end
//     else begin
//         if (!card_detect) begin//Card present
//             if (debounce!=4'b1111)
//                 debounce<=debounce+1'b1;
//         end
//         else
//             debounce<=0;
// 
//         if (debounce==4'b1111)
//             card_present<=1'b1;
//         else
//             card_present<=1'b0;
//     end
// end

assign cmd_o[39:38] = 2'b01;
assign cmd_o[37:32] = command_i[`CMD_INDEX];  //CMD_INDEX
assign cmd_o[31:0] = argument_i; //CMD_Argument

always @(*) begin
    index_check <= command_i[`CMD_IDX_CHECK];
    crc_check <= command_i[`CMD_CRC_CHECK];
    busy_check <= command_i[`CMD_BUSY_CHECK];
end

always @(posedge sd_clk or posedge rst)
begin
    if (rst) begin
        int_status_reg <= 0;
        start_xfr_o <= 0;
        go_idle_o <= 0;

        state <= IDLE;
    end
    else begin
        case(state)
            IDLE: begin
                go_idle_o <= 0;
                if (command_i[`CMD_RESPONSE_CHECK]  == 2'b10 || command_i[`CMD_RESPONSE_CHECK] == 2'b11) begin
                    expect_response <=  1;
                    long_response <= 1;
                end
                else if (command_i[`CMD_RESPONSE_CHECK] == 2'b01) begin
                    expect_response <= 1;
                    long_response <= 0;
                end
                else begin
                    expect_response <= 0;
                    long_response <= 0;
                end
                if (start_i) begin
                    start_xfr_o <= 1;
                    int_status_reg <= 0;
                end

                // SM Transition
                if (start_i)
                    state <= EXECUTE;
                else
                    state <= IDLE;
            end
            EXECUTE: begin
                start_xfr_o <= 0;
                //Incoming New Status
                begin //if ( req_in_int == 1) begin
                    if (finish_i) begin //Data avaible
                        if (crc_check & !crc_ok_i) begin
                            int_status_reg[`INT_CMD_CCRCE] <= 1;
                            int_status_reg[`INT_CMD_EI] <= 1;
                        end
                        if (index_check & !index_ok_i) begin
                            int_status_reg[`INT_CMD_CIE] <= 1;
                            int_status_reg[`INT_CMD_EI] <= 1;
                        end
                        int_status_reg[`INT_CMD_CC] <= 1;
                        // end
                    end ////Data avaible
                end //Status change

                // SM Transition
                if ((finish_i && !busy_check) || go_idle_o)
                    state <= IDLE;
                else if (finish_i && busy_check)
                    state <= BUSY_CHECK;
                else
                    state <= EXECUTE;
            end //EXECUTE state
            BUSY_CHECK: begin
                start_xfr_o <= 0;
                go_idle_o <= 0;

                // SM Transition
                if (!busy_i)
                    state <= IDLE;
                else
                    state <= BUSY_CHECK;
            end
        endcase
        if (int_status_rst_i)
            int_status_reg <= 0;
    end
end

endmodule
