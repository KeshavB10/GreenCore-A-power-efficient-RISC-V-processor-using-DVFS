module GreenCore_Top(
    input  wire       clk,      // 100 MHz
    input  wire       rst,      // active-high (center button BTNC)
    output reg  [6:0] seg,
    output reg  [3:0] an
);

    // ================================================
    // Parameters
    // ================================================
    parameter RESULT_CONT   = 19;
    parameter TOTAL_RESULTS = 22;

    localparam DISPLAY_TICKS = 200_000_000;   // exactly 2 seconds @ 100 MHz

    // ================================================
    // Processor + DVFS wiring (unchanged)
    // ================================================
    wire        proc_clk;
    wire        complex_instr;
    wire [31:0] proc_result;          // <-- we no longer use instr_done
    wire        waiting =(proc_result == 32'hFFFFFFFF);

    Single_Cycle_Top RISCV_Core(
        .clk          (proc_clk),
        .rst          (rst),
        .complex_instr(complex_instr),
        .proc_result  (proc_result),
        .instr_done   ()                  // unused now
    );

    clock_mux DVFS(
        .clk_100      (clk),
        .reset        (rst),
        .complex_instr(complex_instr),
        .clk_out      (proc_clk)
    );

    // ================================================
    // Result memory (stores 16-bit BCD)
    // ================================================
    reg [15:0] result_mem [0:RESULT_CONT-1];

    reg [4:0] write_ptr = 0;
    reg [4:0] read_ptr  = 0;

    wire program_done = (write_ptr >= TOTAL_RESULTS);   // <-- entire program finished

    // ================================================
    // NEW STORAGE LOGIC (change detection - NO instr_done)
    // ================================================
    reg [31:0] prev_proc_result = 0;
    wire [15:0] bcd_digits;

    binary_to_bcd bcd_converter(
        .binary(proc_result[15:0]),   // 16-bit value as per your requirement
        .bcd   (bcd_digits)
    );

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            write_ptr         <= 0;
            prev_proc_result  <= 32'd0;
        end
        else if (!program_done) begin
            // Store ONLY when proc_result actually changes (new value appeared)
            if (proc_result != prev_proc_result) begin
                result_mem[write_ptr] <= bcd_digits;   // snapshot of BCD
                prev_proc_result      <= proc_result;
                write_ptr             <= write_ptr + 1;
            end
        end
    end

    // ================================================
    // Playback control (starts ONLY after program_done)
    // ================================================
    reg [27:0] delay_cnt   = 0;
    reg [15:0] display_bcd = 16'h0000;   // what we actually show on the 7-seg

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            read_ptr    <= 0;
            delay_cnt   <= 0;
            display_bcd <= 16'hE100;
        end
        else if (program_done) begin
            if (delay_cnt >= DISPLAY_TICKS-1) begin
                delay_cnt <= 0;
                
                if (result_mem[read_ptr] == 32'h5535) begin
                    display_bcd <= 16'hFFFF;
                end
                else begin
                    display_bcd <= result_mem[read_ptr];   // load next result for 2 seconds
                end 
                
                if (read_ptr == TOTAL_RESULTS-1)
                    read_ptr <= 0;                     // loop forever
                else
                    read_ptr <= read_ptr + 1;
            end
            else begin
                delay_cnt <= delay_cnt + 1;
            end
        end
        else begin
            display_bcd <= 16'h0000;   // during collection phase → blank
        end
    end

    // ================================================
    // Fast digit multiplexing (~400 Hz full refresh)
    // ================================================
    reg [15:0] refresh_cnt = 0;
    always @(posedge clk) refresh_cnt <= refresh_cnt + 1;

    wire [1:0] digit_sel = refresh_cnt[15:14];   // adjust if you want different speed

    // Select current digit (MSB leftmost)
    reg [3:0] current_digit;
    always @* begin
        case (digit_sel)
            2'd0: current_digit = display_bcd[15:12];
            2'd1: current_digit = display_bcd[11:8];
            2'd2: current_digit = display_bcd[7:4];
            2'd3: current_digit = display_bcd[3:0];
        endcase
    end

    // ================================================
    // 7-Segment drive (Basys3 common-anode polarity)
    // ================================================
    function [6:0] hex_to_seg;
        input [3:0] hex;
        begin
            case (hex)
                4'h0: hex_to_seg = 7'b0111111;
                4'h1: hex_to_seg = 7'b0000110;
                4'h2: hex_to_seg = 7'b1011011;
                4'h3: hex_to_seg = 7'b1001111;
                4'h4: hex_to_seg = 7'b1100110;
                4'h5: hex_to_seg = 7'b1101101;
                4'h6: hex_to_seg = 7'b1111101;
                4'h7: hex_to_seg = 7'b0000111;
                4'h8: hex_to_seg = 7'b1111111;
                4'h9: hex_to_seg = 7'b1101111;
                4'hA: hex_to_seg = 7'b1110111;
                4'hE: hex_to_seg = 7'b1111001;
                4'hF: hex_to_seg = 7'b1000000;
                default: hex_to_seg = 7'b0000000;
            endcase
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            an  <= 4'b1111;
            seg <= 7'b1111111;
        end
        else begin
            // Anode enable (active-low)
            case (digit_sel)
                2'd0: an <= 4'b0111;  // leftmost
                2'd1: an <= 4'b1011;
                2'd2: an <= 4'b1101;
                2'd3: an <= 4'b1110;  // rightmost
            endcase

            // Segment drive (active-low → invert your active-high pattern)
            seg <= ~hex_to_seg(current_digit);
        end
    end

endmodule
