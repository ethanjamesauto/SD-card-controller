module byte_en_reg 
#(
    parameter DATA_WIDTH = 32,
    parameter SEL_WIDTH = 2
)
(
    input clk,
    input rst,
    input we,
    input [SEL_WIDTH - 1:0] byte_sel,
    input [7:0] byte_in,
    output [7:0] byte_out,
    output reg [DATA_WIDTH - 1:0] data_out
);

assign byte_out = byte_sel == 2'b00 ? data_out[7:0] :
                  byte_sel == 2'b01 ? data_out[15:8] :
                  byte_sel == 2'b10 ? data_out[23:16] :
                  byte_sel == 2'b11 ? data_out[31:24] : 0;

always @(posedge clk) begin
    if (rst) begin
        data_out <= 0;
    end else if (we) begin
        case (byte_sel)
            2'b00: data_out[7:0] <= byte_in;
            2'b01: data_out[15:8] <= byte_in;
            2'b10: data_out[23:16] <= byte_in;
            2'b11: data_out[31:24] <= byte_in;
        endcase
    end
end

endmodule
