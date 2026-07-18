module Single_Cycle_Top(clk,rst,complex_instr,proc_result,instr_done); //==================keshu

    input clk,rst;
    output complex_instr;
    output [31:0] proc_result;
    output instr_done; //=========================keshu

    wire [31:0] PC_Top,RD_Instr,RD1_Top,Imm_Ext_Top,ALUResult,ReadData,PCPlus4,RD2_Top,SrcB,Result;
    wire RegWrite,MemWrite,ALUSrc,ResultSrc;
    wire [1:0]ImmSrc;
    wire [2:0]ALUControl_Top;

    wire [31:0] ALU_or_MEM_Result; //currently result comes form Memory or ALU Result, so add a third result possibility which is Mul_result
    
    wire isMUL;
    wire mul_done;
    wire [31:0] mul_result;

    assign complex_instr=isMUL; //ORing all complex instructions
    assign instr_done= RegWrite & (~isMUL | mul_done); //==================keshu


    wire mul_start;
    reg prev_isMUL; //to remember we were already in a MUL instruction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            prev_isMUL <= 1'b0;
        end
        else begin
            prev_isMUL <= isMUL && !mul_done; //reset after MUL done
        end
    end

    assign mul_start= isMUL && !prev_isMUL;   //one cycle pulse

    PC_Module PC(
        .clk(clk),
        .rst(rst),
        .PC(PC_Top),
        .PC_Next((isMUL && !mul_done) ? PC_Top : PCPlus4) // (PC + 4) must stall when multiplication is busy, till then same PC is PC value
    );

    PC_Adder PC_Adder(
                    .a(PC_Top),
                    .b(32'd4),
                    .c(PCPlus4)
    );
    
    Instruction_Memory Instruction_Memory(
                            .rst(rst),
                            .A(PC_Top),
                            .RD(RD_Instr)
    );

    Register_File Register_File(
                            .clk(clk),
                            .rst(rst),
                            .WE3(RegWrite & (~isMUL | mul_done)), //for normal instructions write as usual, if MUL write when mul_done
                            .WD3(Result),
                            .A1(RD_Instr[19:15]),
                            .A2(RD_Instr[24:20]),
                            .A3(RD_Instr[11:7]),
                            .RD1(RD1_Top),
                            .RD2(RD2_Top)
    );

    Sign_Extend Sign_Extend(
                        .In(RD_Instr),
                        .ImmSrc(ImmSrc[0]),
                        .Imm_Ext(Imm_Ext_Top)
    );

    Mux Mux_Register_to_ALU(
                            .a(RD2_Top),
                            .b(Imm_Ext_Top),
                            .s(ALUSrc),
                            .c(SrcB)
    );

    ALU ALU(
            .A(RD1_Top),
            .B(SrcB),
            .Result(ALUResult),
            .ALUControl(ALUControl_Top),
            .OverFlow(),
            .Carry(),
            .Zero(),
            .Negative()
    );


    complex_mult MUL_UNIT(
                        .clk(clk),
                        .rst(rst),
                        .start(mul_start),
                        .a(RD1_Top),
                        .b(RD2_Top),
                        .done(mul_done),
                        .result(mul_result)
    );


    Control_Unit_Top Control_Unit_Top(
                            .Op(RD_Instr[6:0]),
                            .RegWrite(RegWrite),
                            .ImmSrc(ImmSrc),
                            .ALUSrc(ALUSrc),
                            .MemWrite(MemWrite),
                            .ResultSrc(ResultSrc),
                            .Branch(),
                            .funct3(RD_Instr[14:12]),
                            .funct7(RD_Instr[31:25]),
                            .ALUControl(ALUControl_Top),
                            .isMUL(isMUL)
    );

    Data_Memory Data_Memory(
                        .clk(clk),
                        .rst(rst),
                        .WE(MemWrite),
                        .WD(RD2_Top),
                        .A(ALUResult),
                        .RD(ReadData)
    );

    Mux Mux_DataMemory_to_Register(
                            .a(ALUResult),
                            .b(ReadData),
                            .s(ResultSrc),
                            .c(ALU_or_MEM_Result) //earlier it was .c(Result)
    );

    assign Result = (isMUL && mul_done) ? mul_result : ALU_or_MEM_Result;
    assign proc_result =(instr_done)? Result : 32'hFFFFFFFF;

endmodule

module ALU(A,B,Result,ALUControl,OverFlow,Carry,Zero,Negative);

    input [31:0]A,B;
    input [2:0]ALUControl;
    output Carry,OverFlow,Zero,Negative;
    output [31:0]Result;

    wire Cout;
    wire [31:0]Sum;

    assign {Cout,Sum} = (ALUControl[0] == 1'b0) ? A + B :
                                          (A + ((~B)+1)) ;
    assign Result = (ALUControl == 3'b000) ? Sum :
                    (ALUControl == 3'b001) ? Sum :
                    (ALUControl == 3'b010) ? A & B :
                    (ALUControl == 3'b011) ? A | B :
                    (ALUControl == 3'b101) ? {{31{1'b0}},(Sum[31])} : {32{1'b0}};
    
    assign OverFlow = ((Sum[31] ^ A[31]) & 
                      (~(ALUControl[0] ^ B[31] ^ A[31])) &
                      (~ALUControl[1]));
    assign Carry = ((~ALUControl[1]) & Cout);
    assign Zero = &(~Result);
    assign Negative = Result[31];

endmodule
module ALU_Decoder(ALUOp,funct3,funct7,op,ALUControl,isMUL);

    input [1:0]ALUOp;
    input [2:0]funct3;
    input [6:0]funct7,op;
    output reg [2:0]ALUControl;
    output reg isMUL;

    always @(*) begin
        ALUControl = 3'b000;
        isMUL      = 1'b0;

        if (ALUOp==2'b10) begin
            case (funct3)
                3'b000: begin
                    if ({op[5],funct7[5]} == 2'b11) begin
                        ALUControl = 3'b001; //SUB
                    end
                    else begin
                        ALUControl = 3'b000; //AND
                    end
                end
                3'b010: ALUControl = 3'b101; //SLT
                3'b110: ALUControl = 3'b011; //OR
                3'b111: ALUControl = 3'b010; //AND
                3'b100: 
                    if (funct7 ==7'b0) begin
                        isMUL = 1'b1; //to tell CPU this a MUL instruction
                        ALUControl = 3'b000; //Dummy (ALU not used)
                    end
                default: ALUControl = 3'b000;
            endcase
        end
    end 

endmodule
module Control_Unit_Top(Op,RegWrite,ImmSrc,ALUSrc,MemWrite,ResultSrc,Branch,funct3,funct7,ALUControl,isMUL);

    input [6:0]Op,funct7;
    input [2:0]funct3;
    output RegWrite,ALUSrc,MemWrite,ResultSrc,Branch;
    output [1:0]ImmSrc;
    output [2:0]ALUControl;
    output isMUL;

    wire [1:0]ALUOp;

    Main_Decoder Main_Decoder(
                .Op(Op),
                .RegWrite(RegWrite),
                .ImmSrc(ImmSrc),
                .MemWrite(MemWrite),
                .ResultSrc(ResultSrc),
                .Branch(Branch),
                .ALUSrc(ALUSrc),
                .ALUOp(ALUOp)
    );

    ALU_Decoder ALU_Decoder(
                            .ALUOp(ALUOp),
                            .funct3(funct3),
                            .funct7(funct7),
                            .op(Op),
                            .ALUControl(ALUControl),
                            .isMUL(isMUL)   //NEW
    );


endmodule
module Data_Memory(clk,rst,WE,WD,A,RD);

    input clk,rst,WE;
    input [31:0]A,WD;
    output [31:0]RD;

    reg [31:0] mem [1023:0];
    
    always @(posedge clk or posedge rst) begin
    if (rst) begin
        mem[6] <= 32'h0000000A;
    end
    else if (WE)
        mem[A] <= WD;
end
    assign RD = (rst) ? 32'd0 : mem[A];
endmodule

module Instruction_Memory(rst,A,RD);

  input rst;
  input [31:0]A;
  output [31:0]RD;

  reg [31:0] mem [1023:0];
  
  assign RD =  mem[A[31:2]]; //earlier (rst) ? 32'd0 : mem[A[31:2]];
    
    initial begin
        $readmemh("C:\\Users\\kesha\\OneDrive\\Desktop\\Final_Project\\Greencore\\Greencore.srcs\\sources_1\\new\\instructions.hex", mem);
    end



endmodule
module Main_Decoder(Op,RegWrite,ImmSrc,ALUSrc,MemWrite,ResultSrc,Branch,ALUOp);
    input [6:0]Op;
    output RegWrite,ALUSrc,MemWrite,ResultSrc,Branch;
    output [1:0]ImmSrc,ALUOp;

    assign RegWrite = (Op == 7'b0000011 | Op == 7'b0110011) ? 1'b1 :
                                                              1'b0 ;
    assign ImmSrc = (Op == 7'b0100011) ? 2'b01 : 
                    (Op == 7'b1100011) ? 2'b10 :    
                                         2'b00 ;
    assign ALUSrc = (Op == 7'b0000011 | Op == 7'b0100011| Op == 7'b0010011) ? 1'b1 :
                                                            1'b0 ;
    assign MemWrite = (Op == 7'b0100011) ? 1'b1 :
                                           1'b0 ;
    assign ResultSrc = (Op == 7'b0000011) ? 1'b1 :
                                            1'b0 ;
    assign Branch = (Op == 7'b1100011) ? 1'b1 :
                                         1'b0 ;
    assign ALUOp = (Op == 7'b0110011) ? 2'b10 :
                   (Op == 7'b1100011) ? 2'b01 :
                                        2'b00 ;

endmodule
module Mux (a,b,s,c);

    input [31:0]a,b;
    input s;
    output [31:0]c;

    assign c = (~s) ? a : b ;
    
endmodule
module PC_Module(clk,rst,PC,PC_Next);
    input clk,rst;
    input [31:0]PC_Next;
    output [31:0]PC;
    reg [31:0]PC;

    reg first_cycle;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 0;
            first_cycle <= 1;
        end
        else if (first_cycle) begin
            PC <= 0; //Hold PC at 0 for one cycle after reset;
            first_cycle <= 0;
        end
        else begin
            PC <= PC_Next;
        end

    end
endmodule
module PC_Adder (a,b,c);

    input [31:0]a,b;
    output [31:0]c;

    assign c = a + b;
    
endmodule
module Register_File(clk,rst,WE3,WD3,A1,A2,A3,RD1,RD2);

    input clk,rst,WE3;
    input [4:0]A1;
    input [4:0]A2;
    input [4:0]A3;
    input [31:0]WD3;
    output [31:0]RD1,RD2;

    reg [31:0] Register [31:0];
    integer i;

    always @(posedge clk or posedge rst)
    begin
        if (rst) begin
            for ( i = 0; i < 32; i = i + 1) begin 
                Register[i] <= 32'd0; 
             end
            
            Register[1]   <= 32'h00000001;
            Register[2]   <= 32'h00000002;
            Register[3]   <= 32'h00000003;
            Register[4]   <= 32'h00000004;
            Register[5]   <= 32'h00000005;
            Register[6]   <= 32'h00000006;
            Register[7]   <= 32'h00000007;
            Register[8]   <= 32'h00000008;
            Register[9]   <= 32'h00000009;
            Register[10]  <= 32'h0000000A;
            Register[11]  <= 32'h0000000B;
            Register[12]  <= 32'h0000000C;
            Register[13]  <= 32'h0000000D;
            Register[14]  <= 32'h0000000E;
            Register[15]  <= 32'h0000000F;
        end
        else if(WE3)
            Register[A3] <= WD3;
    end

    assign RD1 = Register[A1]; //earlier (rst) ? 32'd0 : Register[A1];
    assign RD2 = Register[A2]; //(rst) ? 32'd0 : Register[A2];
        
endmodule
module Sign_Extend (In,Imm_Ext,ImmSrc);

    input [31:0]In;
    input ImmSrc;
    output [31:0]Imm_Ext;

    assign Imm_Ext = (ImmSrc == 1'b1) ? ({{20{In[31]}},In[31:25],In[11:7]}):
                                        {{20{In[31]}},In[31:20]};
                                
endmodule
