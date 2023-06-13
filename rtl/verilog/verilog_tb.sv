module verilog_tb();

reg clk = 0;
reg rst = 0;

initial repeat (512) #1 clk = ~clk;

initial begin
    $dumpfile("verilog_tb.vcd");
    $dumpvars;
    #3 rst = 1;
    #2 rst = 0;
end

sdc_controller sdc_controller_inst (
    .wb_clk_i(clk),
    .wb_rst_i(rst)
);

endmodule