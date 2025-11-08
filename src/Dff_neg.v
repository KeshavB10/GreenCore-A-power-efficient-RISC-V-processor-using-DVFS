module Dff_neg(clk,reset,d,q,qbar);
    input clk,reset,d;
    output reg q,qbar;

    always @(negedge clk or posedge reset) begin
        if (reset) begin
            q<=0;
            qbar<=1;
        end
        else begin
            q<= d;
            qbar<=~d;
        end
    end
endmodule