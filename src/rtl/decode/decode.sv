`ifndef __DECODE_SV
`define __DECODE_SV

`include "instr.pkg"
`include "instr_decode.pkg"
`include "vroom_macros.sv"
`include "gen_funcs.pkg"
`include "common.pkg"

module decode
    import instr::*, instr_decode::*, gen_funcs::*, common::*;
(
    input  logic             clk,
    input  logic             reset,
    input  logic             valid_fe1,
    input  t_instr_pkt       instr_fe1,
    input  logic             stall,
    input  logic             br_mispred_rb1,

    output t_uinstr          uinstr_de0,

    output t_uinstr          uinstr_de1
);

localparam DE0 = 0;
localparam DE1 = 1;
localparam NUM_DE_STAGES = 1;

`MKPIPE(logic,    valid_dex,  DE0, NUM_DE_STAGES)

//
// Nets
//

t_rv_instr        rv_instr_fe1;
t_rv_instr_format ifmt_de0;

`ifdef SIMULATION
int instr_cnt_inst;
`DFF(instr_cnt_inst, reset ? '0 : instr_cnt_inst + int'(valid_dex[DE0]), clk)
`endif

//
// Logic
//

always_comb rv_instr_fe1 = instr_fe1.instr;

//
// DE0
//

always_comb valid_dex[DE0] = valid_fe1 & ~reset;
always_comb ifmt_de0       = get_instr_format(rv_instr_fe1.opcode);

always_comb begin
    uinstr_de0 = '0;
    uinstr_de0.opcode = rv_instr_fe1.opcode;
    uinstr_de0.valid  = valid_dex[DE0];
    uinstr_de0.ifmt   = ifmt_de0;
    uinstr_de0.pc     = instr_fe1.pc;

    unique case (ifmt_de0)
        RV_FMT_R: begin
            uinstr_de0.funct7 = rv_instr_fe1.d.R.funct7;
            uinstr_de0.funct3 = rv_instr_fe1.d.R.funct3;
            if (~rv_instr_fe1.opcode[3]) begin
                // 64b version
                uinstr_de0.dst    = '{opreg: rv_instr_fe1.d.R.rd,  optype: OP_REG, opsize: SZ_8B};
                uinstr_de0.src1   = '{opreg: rv_instr_fe1.d.R.rs1, optype: OP_REG, opsize: SZ_8B};
                uinstr_de0.src2   = '{opreg: rv_instr_fe1.d.R.rs2, optype: OP_REG, opsize: SZ_8B};
            end else begin
                // 32b (W-suffix) version
                uinstr_de0.dst    = '{opreg: rv_instr_fe1.d.R.rd,  optype: OP_REG, opsize: SZ_4B};
                uinstr_de0.src1   = '{opreg: rv_instr_fe1.d.R.rs1, optype: OP_REG, opsize: SZ_4B};
                uinstr_de0.src2   = '{opreg: rv_instr_fe1.d.R.rs2, optype: OP_REG, opsize: SZ_4B};
            end
            uinstr_de0.imm64  = '0;
            uinstr_de0.uop    = rv_instr_to_uop(rv_instr_fe1);
        end
        RV_FMT_I: begin
            uinstr_de0.funct7 = '0;
            uinstr_de0.funct3 = rv_instr_fe1.d.I.funct3;
            if (~rv_instr_fe1.opcode[3]) begin
                // 64b version
                uinstr_de0.dst    = '{opreg: rv_instr_fe1.d.I.rd,  optype: OP_REG, opsize: SZ_8B};
                uinstr_de0.src1   = '{opreg: rv_instr_fe1.d.I.rs1, optype: OP_REG, opsize: SZ_8B};
                uinstr_de0.src2   = '{opreg: '0,                   optype: OP_IMM, opsize: SZ_8B};
            end else begin
                // 32b (W-suffix) version
                uinstr_de0.dst    = '{opreg: rv_instr_fe1.d.I.rd,  optype: OP_REG, opsize: SZ_4B};
                uinstr_de0.src1   = '{opreg: rv_instr_fe1.d.I.rs1, optype: OP_REG, opsize: SZ_4B};
                uinstr_de0.src2   = '{opreg: '0,                   optype: OP_IMM, opsize: SZ_4B};
            end
            uinstr_de0.imm64  = sext_funcs#(.IWIDTH(12), .OWIDTH(64))::sext(rv_instr_fe1.d.I.imm_11_0);
            uinstr_de0.uop    = rv_instr_to_uop(rv_instr_fe1);
        end
        RV_FMT_S: begin
        end
        RV_FMT_J: begin
        end
        RV_FMT_B: begin
            uinstr_de0.funct7 = '0;
            uinstr_de0.funct3 = rv_instr_fe1.d.B.funct3;
            uinstr_de0.dst    = '{opreg: '0, optype: OP_INVD, opsize: SZ_4B};
            uinstr_de0.src1   = '{opreg: rv_instr_fe1.d.B.rs1, optype: OP_REG, opsize: SZ_4B};
            uinstr_de0.src2   = '{opreg: rv_instr_fe1.d.B.rs2, optype: OP_REG, opsize: SZ_4B};
            uinstr_de0.imm64  = sext_funcs#(.IWIDTH(13), .OWIDTH(64))::sext({rv_instr_fe1.d.B.imm_12,
                                                                             rv_instr_fe1.d.B.imm_11,
                                                                             rv_instr_fe1.d.B.imm_10_5,
                                                                             rv_instr_fe1.d.B.imm_4_1,
                                                                             1'b0});
            uinstr_de0.uop    = rv_instr_to_uop(rv_instr_fe1);
        end
        RV_FMT_U: begin
        end
        default: begin
        end
    endcase

    `ifdef SIMULATION
    uinstr_de0.SIMID     = instr_fe1.SIMID;
    //uinstr_de0.SIMID.did = instr_cnt_inst;
    `endif

    if (reset) uinstr_de0 = '0;
end

//
// DE1/RD0
//

t_uinstr uinstr_nq_de1;
`DFF_EN(uinstr_nq_de1, uinstr_de0, clk, ~stall)

always_comb begin
    uinstr_de1 = uinstr_nq_de1;
    uinstr_de1.valid  &= ~br_mispred_rb1;
end

//
// Debug
//

`ifdef SIMULATION
always @(posedge clk) begin
    if (uinstr_de0.valid & ~stall) begin
        `INFO(("unit:DE %s", describe_uinstr(uinstr_de0)))
    end
end
`endif

`ifdef ASSERT
//chk_no_change #(.T(t_uinstr)) cnc ( .clk, .reset, .hold(stall & uinstr_de1.valid & ~br_mispred_rb1), .thing(uinstr_de1) );
`endif

endmodule

`endif // __DECODE_SV

