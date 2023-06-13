//////////////////////////////////////////////////////////////////////
////                                                              ////
//// WISHBONE SD Card Controller IP Core                          ////
////                                                              ////
//// byte_en_reg.v                                                ////
////                                                              ////
//// This file is part of the WISHBONE SD Card                    ////
//// Controller IP Core project                                   ////
//// http://opencores.org/project,sd_card_controller              ////
////                                                              ////
//// Description                                                  ////
//// Register with byte enable. (write is performe only to        //// 
//// enebled bytes)                                               ////
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

module byte_en_reg (
    clk,
    rst,
    we,
    byte_sel,
    d_byte,
    q_byte,
    q
    );

parameter DATA_W_BYTES = 4;
parameter SEL_WIDTH = 2;

input clk;
input rst;
input we;

input [SEL_WIDTH - 1:0] byte_sel;
input [7:0] d_byte;
output [7:0] q_byte;

output reg [7:0] q [DATA_W_BYTES-1:0];

assign q_byte = q[byte_sel];

always @(posedge clk)
begin
    int i;

    if (rst)
        for (i = 0; i < DATA_W_BYTES; i = i + 1)
            q[i] <= 8'h00;
    else begin
        if (we)
            q[byte_sel] <= d_byte;
    end
end

endmodule
