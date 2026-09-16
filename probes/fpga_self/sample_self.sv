// TARGET ARTIFACT — hand-written sketch of what `self|fpga` should emit
// for the probe kernel. This file defines the shape the emitter writes;
// it is NOT generated.
//
//   std/kernel:init(Sample) |> std/kernel:self { k.value *= 2 }
//
// Port widths are read off the |fpga facet's meet, not the proto's i64:
//   value: i64 & >=0 & <=255  ->  [7:0]
//   mode:  i64 & >=0 & <=3    ->  [1:0]
// An unconstrained i64 would emit [63:0] — 8x the LUTs for bits that can
// never carry information.
//
// One self op = one pipeline stage = one beat. in_valid/out_valid is the
// stream handshake; the stage accepts one Sample per clock after reset.
//
// SEMANTIC PIN (unruled): `value *= 2` on [7:0] truncates mod 256 —
// 200*2 wraps to 144. A `clamp`-claimed facet would emit saturation
// instead. Which the facet's atoms should force is the width-semantics
// question, same class as beat semantics.

module sample_self (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       in_valid,
    input  logic [7:0] in_value,
    input  logic [1:0] in_mode,
    output logic       out_valid,
    output logic [7:0] out_value,
    output logic [1:0] out_mode
);
    // self { k.value *= 2 } — the element transform is combinational;
    // the stage register is the pipeline beat. mode flows through
    // untouched, the way fields the body doesn't mention do.
    logic [7:0] mapped_value;
    assign mapped_value = in_value * 8'd2;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_valid <= 1'b0;
            out_value <= 8'd0;
            out_mode  <= 2'd0;
        end else begin
            out_valid <= in_valid;
            out_value <= mapped_value;
            out_mode  <= in_mode;
        end
    end
endmodule
