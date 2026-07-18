module complex_mult(clk,rst,start,a,b,done,result); //combining the DP and CP of Complex multiplcation logic for easier integration with RISC-V
    input clk,rst,start;
    input [31:0] a,b;
    output done;
    output [31:0] result;
    
    //Control Signals
    wire LdA,LdB,LdP,clrP,decB;
    wire eqz;

    wire [31:0] P_out;

    //instantiating main blocks
    MUL_data_path DP(
        .eqz(eqz),
        .LdA(LdA),
        .LdB(LdB),
        .LdP(LdP),
        .clrP(clrP),
        .decB(decB),
        .A_in(a),
        .B_in(b),
        .clk(clk),
        .P_out(P_out),
        .rst(rst)
    );

    MUL_controller CP(
        .LdA(LdA),
        .LdB(LdB),
        .LdP(LdP),
        .clrP(clrP),
        .decB(decB),
        .done(done),
        .eqz(eqz),
        .start(start),
        .clk(clk),
        .rst(rst)
    );

    assign result= P_out; //PIPO2 Output is out output which is stored in result 

endmodule



module MUL_data_path(eqz,LdA,LdB,LdP,clrP,decB,A_in,B_in,clk,P_out,rst);
    input LdA,LdB,LdP,clrP,decB,clk,rst;
    input [31:0] A_in,B_in;
    output eqz;
    output [31:0] P_out; //taking the product output outside the DP of the multiplier
    wire [31:0] X,Y,Z,Bout;

    assign P_out=Y;

    //Use the Block diagram as reference for designing the top module

    //Instantiate the modules used in the data path , HERE there are "FIVE" Modules to be instantiated

    //instatiate signals to a module by using the diagram for the data path
    PIPO1 A(X,A_in,LdA,clk,rst);
    PIPO2 P(Y,Z,LdP,clrP,clk,rst);
    CNTR  B(Bout,B_in,LdB,decB,clk,rst);
    ADD adder(Z,X,Y);
    COMP Cmp(eqz,Bout);
endmodule

module MUL_controller(LdA,LdB,LdP,clrP,decB,done,eqz,start,clk,rst);
    input eqz,start,clk,rst;
    output reg LdA,LdB,LdP,clrP,decB,done;
    //inputs and ouputs can be obtained from the block diagram
    //data_in not required in the FSM, only in the testbench

    reg [0:2]state;
    parameter S0=3'b000,S1=3'b001,S2=3'b010,S3=3'b011,S4=3'b100;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <=S0;     //provide rst condition
        end

        else begin
            case (state)
                S0: if (start) state<=S1;
                S1: state<=S2;
                S2: state<=S3;
                S3: if (eqz) state<=S4; //provide a small delay before transitioning to S4 (removed delay #2 cause it is not Synthesisable)
                S4: state<=S0; //remain in S4 //removed comment "if (!start) state <= S0"
                default: state<=S0;
            endcase
        end
    end

    //block for generating the control signals , check the control path diagram

    always @(*) begin
        //defaults
        LdA=0; LdB=0; LdP=0; clrP=0; decB=0; done=0;
        case (state)
            //S0: begin #1 LdA=0; LdB=0; LdP=0;clrP=0;decB=0; end
            S1: begin  LdA=1; end
            S2: begin  LdA=0;LdB=1;clrP=1; end
            S3: begin  
                    if (!eqz) begin 
                    LdB=0; clrP=0;LdP=1;decB=1; 
                    end
                end
            S4: begin  LdP=0; decB=0; done=1;end
            //default: begin #1 LdA=0;LdB=0;LdP=0;clrP=0;decB=0; end
        endcase
    end
endmodule

module ADD(out,a,b);
    input [31:0]a,b;
    output reg [31:0]out;

    always @(*) begin
        out= a+b;
    end
endmodule


module CNTR (out,in,LdB,decB,clk,rst);
    input [31:0]in;
    input LdB,decB,clk,rst;
    output reg [31:0]out;

    always @(posedge clk or posedge rst) begin
        if (rst) begin 
            out <= 32'b0;   //provide rst condition
        end
        else if (LdB) out<=in;
        else if (decB) out<= out-1;
    end
endmodule


module COMP (eqz,in);
    input [31:0]in;
    output  eqz;

    assign eqz=(in==0);
endmodule


module PIPO1(out,in,LdA,clk,rst);
    input [31:0]in;
    input LdA,clk,rst;
    output reg [31:0]out; //as in a always block, since value is being stored

    always @ (posedge clk or posedge rst) begin
        if (rst) begin
            out <=32'b0;    //provide rst condition
        end
        else if (LdA) 
            out<=in;
    end
endmodule


module PIPO2(out,in,LdP,clr,clk,rst);
    input [31:0] in;
    input LdP,clr,clk,rst;
    output reg [31:0]out;

    always @(posedge clk or posedge rst)begin
        if (rst) begin
            out <= 32'b0;   //provide rst condition
        end
        else if(clr) out<=32'b0;
        else if (LdP) out<=in;
    end
endmodule

