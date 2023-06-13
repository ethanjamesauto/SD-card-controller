module verilog_tb();

reg clk = 0;
reg rst = 0;

initial repeat (512) #1 clk = ~clk;

reg [6:0] addr;
reg we = 0;
reg [7:0] data_in;
wire [7:0] data_out;

initial begin
    $dumpfile("verilog_tb.vcd");
    $dumpvars;
    #3 rst = 1;
    #2 rst = 0;
    data_in = 8'b10101010;
    #8 addr = 7'b0000000;
    #2 we = 1;
    #4 we = 0;

    data_in = 8'b01010101;
    #8 addr = 7'b0000011;
    #2 we = 1;
    #4 we = 0;

    data_in = 8'h35;
    #8 addr = 7'b0000100;
    #2 addr = 7'b0000101;
    #2 we = 1;
    #4 we = 0;

    data_in = 8'b11011;
    #8 addr = {7'h38 + 2'b00};
    #8 addr = {7'h44 + 2'b00};

end

sdc_controller sdc_controller_inst (
    .clk(clk),
    .rst(rst),
    .addr(addr),
    .data_in(data_in),
    .data_out(data_out),
    .we(we)
);
/*
byte_en_reg reg0(
    .clk(clk),
    .rst(rst),
    .we(we),
    .byte_sel(byte_sel),
    .byte_in(8'b10101011)
    //.q_byte,
    //.q
);*/

endmodule