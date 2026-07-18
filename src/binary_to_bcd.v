module binary_to_bcd(
    input  [31:0] binary,
    output reg [15:0] bcd   // 4 decimal digits
);

integer i;
reg [47:0] shift;

always @(*) begin
    shift = 48'd0;
    shift[31:0] = binary;

    for (i = 0; i < 32; i = i + 1) begin

        if (shift[35:32] >= 5) shift[35:32] = shift[35:32] + 3;
        if (shift[39:36] >= 5) shift[39:36] = shift[39:36] + 3;
        if (shift[43:40] >= 5) shift[43:40] = shift[43:40] + 3;
        if (shift[47:44] >= 5) shift[47:44] = shift[47:44] + 3;

        shift = shift << 1;
    end

    bcd = shift[47:32];
end

endmodule
