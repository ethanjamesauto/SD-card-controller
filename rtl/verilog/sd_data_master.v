//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// sd_data_master.v                                             ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// State machine resposible for controlling data transfers      ////
//// on 4-bit sd card data interface                              ////
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

module sd_data_master (
           input sd_clk,
           input rst,
           input start_tx_i,
           input start_rx_i,
           input [`DATA_TIMEOUT_W-1:0] timeout_i,
           //Output to SD-Host Reg
           output reg d_write_o,
           output reg d_read_o,
           //To fifo filler
           output reg start_tx_fifo_o,
           output reg start_rx_fifo_o,
           input tx_fifo_empty_i,
           input tx_fifo_full_i,
           input rx_fifo_full_i,
           //TODO: should be dependent on rx_fifo_empty_i signal (wishbone read all data case)
           //SD-DATA_Host
           input xfr_complete_i,
           input crc_ok_i,
           //status output
           output reg [`INT_DATA_SIZE-1:0] int_status_o,
           input int_status_rst_i
       );

reg tx_cycle;
parameter SIZE = 2;
reg [SIZE-1:0] state;
parameter IDLE          = 2'd0;
parameter START_TX_FIFO = 2'd1;
parameter START_RX_FIFO = 2'd2;
parameter DATA_TRANSFER = 2'd3;

reg trans_done;

//Output logic-----------------
always @(posedge sd_clk or posedge rst)
begin
    if (rst) begin
        start_tx_fifo_o <= 0;
        start_rx_fifo_o <= 0;
        d_write_o <= 0;
        d_read_o <= 0;
        trans_done <= 0;
        tx_cycle <= 0;
        int_status_o <= 0;

        state <= IDLE;
    end
    else begin
        case(state)
            IDLE: begin
                start_tx_fifo_o <= 0;
                start_rx_fifo_o <= 0;
                d_write_o <= 0;
                d_read_o <= 0;
                trans_done <= 0;
                tx_cycle <= 0;

                if (start_tx_i == 1) begin
                    state <= START_TX_FIFO;
                end
                else if (start_rx_i == 1) begin
                    state <= START_RX_FIFO;
                end
                else begin
                    state <= IDLE;
                end
            end
            START_RX_FIFO: begin
                start_rx_fifo_o <= 1;
                start_tx_fifo_o <= 0;
                tx_cycle <= 0;
                d_read_o <= 1;

                if (xfr_complete_i == 0)
                    state <= DATA_TRANSFER;
                else
                    state <= START_RX_FIFO;
            end
            START_TX_FIFO:  begin
                start_rx_fifo_o <= 0;
                start_tx_fifo_o <= 1;
                tx_cycle <= 1;
                d_write_o <= 1;

                if (xfr_complete_i == 0)
                    state <= DATA_TRANSFER;
                else
                    state <= START_TX_FIFO;
            end
            DATA_TRANSFER: begin
                d_read_o <= 0;
                d_write_o <= 0;
                if (tx_cycle) begin
                    if (tx_fifo_empty_i) begin
                        if (!trans_done) begin
                            int_status_o[`INT_DATA_CFE] <= 1;
                            int_status_o[`INT_DATA_EI] <= 1;
                        end
                        trans_done <= 1;
                        //stop sd_data_serial_host
                        d_write_o <= 1;
                        d_read_o <= 1;
                    end
                end
                else begin
                    if (rx_fifo_full_i) begin
                        if (!trans_done) begin
                            int_status_o[`INT_DATA_CFE] <= 1;
                            int_status_o[`INT_DATA_EI] <= 1;
                        end
                        trans_done <= 1;
                        //stop sd_data_serial_host
                        d_write_o <= 1;
                        d_read_o <= 1;
                    end
                end
                if (xfr_complete_i) begin //Transfer complete
                    d_write_o <= 0;
                    d_read_o <= 0;
                    trans_done <= 1;
                    if (!crc_ok_i)  begin //Wrong CRC and Data line free.
                        if (!trans_done) begin
                            int_status_o[`INT_DATA_CCRCE] <= 1;
                            int_status_o[`INT_DATA_EI] <= 1;
                        end
                    end
                    else if (crc_ok_i) begin //Data Line free
                        if (!trans_done)
                            int_status_o[`INT_DATA_CC] <= 1;
                    end
                end

                if (trans_done)
                    state <= IDLE;
                else
                    state <= DATA_TRANSFER;
            end
        endcase
        if (int_status_rst_i)
            int_status_o<=0;
    end
end

endmodule
