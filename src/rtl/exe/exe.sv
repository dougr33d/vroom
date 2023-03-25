`ifndef __EXE_SV
`define __EXE_SV

`include "instr.pkg"
`include "vroom_macros.sv"

module exe
    import instr::*, instr_decode::*;
(
    input  logic         clk,
    input  logic         reset,
    input  logic         stall,

    input  t_uinstr      uinstr_rd1,
    input  t_rv_reg_data rddatas_rd1 [1:0],

    output t_uinstr      uinstr_ex1,
    output t_rv_reg_data result_ex1
);

localparam EX0 = 0;
localparam EX1 = 1;
localparam NUM_EX_STAGES = 1;

//
// Nets
//

t_rv_reg_data src1val_ex0;
t_rv_reg_data src2val_ex0;

t_uinstr uinstr_ql_ex0;

logic         ialu_resvld_ex0;
t_rv_reg_data ialu_result_ex0;

`MKPIPE_INIT(t_uinstr,       uinstr_exx, uinstr_ql_ex0, EX0, NUM_EX_STAGES)
`MKPIPE     (t_rv_reg_data,  result_exx,                EX0, NUM_EX_STAGES)

//
// Logic
//

always_comb begin
    uinstr_ql_ex0 = uinstr_rd1;
    `ifdef SIMULATION
    uinstr_ql_ex0.SIMID.src1_val   = src1val_ex0;
    uinstr_ql_ex0.SIMID.src2_val   = src2val_ex0;
    uinstr_ql_ex0.SIMID.result_val = result_exx[EX0];
    `endif
end

//
// EX0
//

always_comb src1val_ex0 = rddatas_rd1[0];
always_comb src2val_ex0 = (uinstr_rd1.src2.optype == OP_REG ? rddatas_rd1[1]   : '0)
                        | (uinstr_rd1.src2.optype == OP_IMM ? uinstr_rd1.imm32 : '0);

// Execution units

ialu ialu (
    .clk,
    .reset,

    .uinstr_ex0  ( uinstr_rd1      ),
    .src1val_ex0,
    .src2val_ex0,

    .resvld_ex0  ( ialu_resvld_ex0 ),
    .result_ex0  ( ialu_result_ex0 )
);

// Combine outputs

always_comb begin
    result_exx[EX0]  = '0;
    result_exx[EX0] |= ialu_resvld_ex0 ? ialu_result_ex0 : '0;
end

//
// EX1
//

always_comb uinstr_ex1 = uinstr_exx[EX1];
always_comb result_ex1 = result_exx[EX1];

//
// Debug
//

`ifdef SIMULATION
always @(posedge clk) begin
    if (uinstr_rd1.valid) begin
        `INFO(("unit:EX %s result:%08h", describe_uinstr(uinstr_rd1), result_exx[EX0]))
    end
end
`endif

/*
`ifdef ASSERT
`VASSERT(a_illegal_format, uinstr_de1.valid, uinstr_de1.ifmt inside {RV_FMT_I,RV_FMT_R}, $sformatf("Unsupported instr fmt: %s", uinstr_de1.ifmt.name()))
`endif
    */

endmodule

`endif // __EXE_SV
