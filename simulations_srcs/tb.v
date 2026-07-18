`timescale 1ns/1ps

module tb_GreenCore;

    reg clk;
    reg rst;

    // 7-seg outputs (just wires in TB)
    wire [6:0] seg;
    wire [3:0] an;

    // Instantiate GreenCore Top
    GreenCore_Top uut (
        .clk(clk),
        .rst(rst),
        .seg(seg),
        .an(an)
    );

    // Clock generation (100 MHz)
    always #5 clk = ~clk;


    initial begin
        clk = 0;
        rst = 1;

        #20;
        rst = 0;

        // Let CPU run
        //#50000;
        #2615;

        $finish;
    end

endmodule
