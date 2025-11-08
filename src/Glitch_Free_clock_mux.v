module clock_mux(clk_100,reset,opcode,clk_out);
    input clk_100,reset;
    input [2:0] opcode;
    output wire clk_out;

    wire [3:0] a,d;
    wire sel_n;
    wire dbar1,dbar3; //qbar of FFs

    wire clk_25;
    wire sel;

    assign sel=(opcode==3'b100)?1:0; //opcode sel bit logic
    assign sel_n=~sel;

    //clock divider
    clock_divider C1(clk_100,reset,clk_25);

    //Faster Clock
    and A11(a[0],sel,dbar3);
    Dff_pos D11(clk_100,reset,a[0],d[0]);
    Dff_neg D12(clk_100,reset,d[0],d[1],dbar1);
    and A12(a[1],d[1],clk_100);

    //Slower clock
    and A21(a[2],sel_n,dbar1);
    Dff_pos D21(clk_25,reset,a[2],d[2]);
    Dff_neg D22(clk_25,reset,d[2],d[3],dbar3);
    and A22(a[3],d[3],clk_25);

    //Final output
    or Or1(clk_out,a[1],a[3]);
endmodule
