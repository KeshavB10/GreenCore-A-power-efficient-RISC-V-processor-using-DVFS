module Dff_pos(clk,reset,d,q);
    input clk,reset,d;
    output reg q;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            q<=0;
        end
        else begin
            q<= d;
        end
    end
endmodule