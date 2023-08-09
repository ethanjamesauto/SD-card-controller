// TODO: validate this design
module byte_en_reg 
#(
    parameter DATA_WIDTH = 32,
    parameter INIT = 0
)
(
    input clk,
    input rst,
    input we,
    input [1:0] byte_sel,
    input [7:0] byte_in,
    output reg [DATA_WIDTH - 1:0] data_out
);

// only needed for 1-bit registers. TODO: why?
localparam OUTPUT_WIDTH = DATA_WIDTH >= 8 ? 8 : DATA_WIDTH;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        data_out <= INIT;
    end else if (we) begin
        data_out[byte_sel * 8 +: OUTPUT_WIDTH] <= byte_in;
    end
end

endmodule
