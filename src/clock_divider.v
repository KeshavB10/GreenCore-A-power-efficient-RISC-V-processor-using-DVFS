module clock_divider(clk_in,reset,clk_out);
    input clk_in, reset;
    output reg clk_out;

    reg [1:0] count;

    always @(posedge clk_in or posedge reset) begin
        if (reset) begin
            clk_out<=1'b0;
            count<=2'b00;
        end
        else begin
            count <= count+1;
            if (count==2'b11) begin
                clk_out<= ~clk_out; //Output toggles after eevery 4th cycle (100 MHz---> 25 MHz)
            end
        end
    end
endmodule
