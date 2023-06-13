module verilog_tb();

reg clk = 0;
reg rst = 0;

initial repeat (512) #1 clk = ~clk;

reg [1:0] byte_sel = 2'd0;
reg we = 1'b0;

initial begin
    $dumpfile("verilog_tb.vcd");
    $dumpvars;
    #3 rst = 1;
    #2 rst = 0;
    #2 we = 1'b1;
    #2 we = 1'b0;
    #10 byte_sel = 2'd1;
    #2 we = 1'b1;
    #2 we = 1'b0;
end

sdc_controller sdc_controller_inst (
    .clk(clk),
    .rst(rst)
);

byte_en_reg reg0(
    .clk(clk),
    .rst(rst),
    .we(we),
    .byte_sel(byte_sel),
    .d_byte(8'h32)
    //.q_byte,
    //.q
);

endmodule