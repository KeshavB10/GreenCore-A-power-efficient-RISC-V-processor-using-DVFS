module mux_tb;
    reg clk_in, reset;
    reg [2:0] opcode;
    wire clk_out;

    clock_mux B1(clk_in,reset,opcode,clk_out);

    initial clk_in=0;
    always #5 clk_in= ~clk_in;

    initial begin
        $dumpfile("Clock_mux.vcd");
        $dumpvars(0, mux_tb);
        reset=1;
        opcode=000; //ADD instruction
        #6 reset=0;
        #4;#250;
        opcode=100; //MUL Instruction
        #10;#500;
        opcode=001; //SUB Instruction
        #10;#2000 $finish;
    end
endmodule