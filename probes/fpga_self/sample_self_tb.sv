// Testbench for sample_self — drives the same three elements the probe
// kernel inits ({4,1},{8,2},{16,3}) on consecutive beats and checks the
// pipeline emits doubled values one beat later. This is the iverilog
// analogue of spirv-val: the gate that proves the artifact computes.
//
// Timing: inputs drive at negedge (stable for the next posedge sample);
// outputs are checked at the following negedge — mid-cycle, after the
// stage register has settled.

module tb;
    logic clk = 0;
    logic rst_n = 0;
    logic in_valid = 0;
    logic [7:0] in_value = 0;
    logic [1:0] in_mode = 0;
    logic out_valid;
    logic [7:0] out_value;
    logic [1:0] out_mode;

    sample_self dut (.*);

    always #5 clk = ~clk;

    int errors = 0;

    task check(input [7:0] exp_v, input [1:0] exp_m);
        if (!out_valid || out_value !== exp_v || out_mode !== exp_m) begin
            $display("FAIL: got valid=%b value=%0d mode=%0d, want value=%0d mode=%0d",
                     out_valid, out_value, out_mode, exp_v, exp_m);
            errors++;
        end else begin
            $display("ok: value=%0d mode=%0d", out_value, out_mode);
        end
    endtask

    initial begin
        @(negedge clk); rst_n = 1;

        // beat 1: push {4,1}
        @(negedge clk); in_valid = 1; in_value = 8'd4;  in_mode = 2'd1;
        // beat 2: stage emitted {8,1}; push {8,2}
        @(negedge clk); check(8'd8,  2'd1);
                        in_value = 8'd8;  in_mode = 2'd2;
        // beat 3: stage emitted {16,2}; push {16,3}
        @(negedge clk); check(8'd16, 2'd2);
                        in_value = 8'd16; in_mode = 2'd3;
        // beat 4: stage emitted {32,3}; drain
        @(negedge clk); check(8'd32, 2'd3);
                        in_valid = 0;

        if (errors == 0) $display("PASS: sample_self pipeline");
        else             $display("FAIL: %0d errors", errors);
        $finish;
    end
endmodule
