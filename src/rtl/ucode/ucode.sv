`ifndef __UCODE_SV
`define __UCODE_SV

`include "instr.pkg"
`include "instr_decode.pkg"
`include "asm.pkg"
`include "vroom_macros.sv"
`include "gen_funcs.pkg"
`include "common.pkg"
`include "verif.pkg"

module ucode
    import instr::*, instr_decode::*, asm::*, gen_funcs::*, common::*, verif::*;
(
    input  logic             clk,
    input  logic             reset,
    input  t_nuke_pkt        nuke_rb1,
    input  logic             rename_ready_rn0,

    input  logic             valid_de1,
    input  t_uinstr          uinstr_de1,
    output logic             ucode_ready_uc0,

    output logic             valid_uc0,
    output t_uinstr          uinstr_uc0
);

//
// Types
//

typedef enum logic {
    UC_IDLE,
    UC_FETCH
} t_uc_fsm;
t_uc_fsm fsm, fsm_nxt;

//
// Nets
//

t_rom_addr useq_pc;
t_rom_addr useq_pc_nxt;
logic      trap_now_de1;
logic      ucrom_active_uc0;

t_uinstr ROM [UCODE_ROM_ROWS-1:0];

//
// FSM
//

assign trap_now_de1 = fsm == UC_IDLE & valid_de1 & rename_ready_rn0 & uinstr_de1.trap_to_ucode;

always_comb begin
    fsm_nxt = fsm;
    if (reset) begin
        fsm_nxt = UC_IDLE;
    end else begin
        unique casez(fsm)
            UC_IDLE:  if (trap_now_de1                                           ) fsm_nxt = UC_FETCH;
            UC_FETCH: if (valid_uc0 & rename_ready_rn0 & uinstr_uc0.eom          ) fsm_nxt = UC_IDLE;
        endcase
    end
end
`DFF(fsm, fsm_nxt, clk)

assign ucrom_active_uc0 = fsm == UC_FETCH;

//
// Logic
//

// useq

always_comb begin
    useq_pc_nxt = useq_pc;
    if (fsm == UC_IDLE) begin
        useq_pc_nxt = uinstr_de1.rom_addr;
    end else begin
        useq_pc_nxt += (valid_uc0 & rename_ready_rn0) ? t_rom_addr'(1) : '0;
    end
end
`DFF(useq_pc, useq_pc_nxt, clk)

assign ucode_ready_uc0 = fsm == UC_IDLE & rename_ready_rn0;

assign valid_uc0  = fsm == UC_IDLE & valid_de1
                  | fsm == UC_FETCH;

t_uinstr trapped_uinstr;
`DFF_EN(trapped_uinstr, uinstr_de1, clk, trap_now_de1)

`ifdef SIMULATION
`SIMID_SPAWN_CNTR(SIMID_UROM, (fsm == UC_FETCH & rename_ready_rn0), clk, trapped_uinstr.SIMID, UCROM)
`endif

always_comb begin
    unique casez (fsm)
        UC_IDLE: begin
            uinstr_uc0 = uinstr_de1;
        end
        UC_FETCH: begin
            uinstr_uc0 = ROM[useq_pc];
            `ifdef SIMULATION
            uinstr_uc0.SIMID = SIMID_UROM;
            `endif
        end
    endcase
end

//
// ROM
//

always_comb begin
    int r;

    for (r=0; r<UCODE_ROM_ROWS; r++) begin
        ROM[r] = f_decode_rv_instr(rvEBREAK());
    end

    r = int'(ROM_ENT_MUL);
    ROM[r] = f_decode_rv_instr(rvADDI(REG_X22, 0, 12'hABC), 1'b0); r++;
    ROM[r] = f_decode_rv_instr(rvADDI(REG_X23, 0, 12'hDEF), 1'b0); r++;
    ROM[r] = f_decode_rv_instr(rvADDI(REG_X24, 0, 12'h123));       r++;

    r = int'(ROM_ENT_DIV);
    ROM[r] = f_decode_rv_instr(rvADDI(23, 0, 12'hDEF)); ROM[r].eom = 1'b1; r++;
end

//
// Debug
//

`ifdef ASSERT
`endif

`ifdef SIMULATION
always @(posedge clk) begin
    if (valid_uc0 & rename_ready_rn0) begin
        unique casez (fsm)
            UC_IDLE:  `UINFO(uinstr_uc0.SIMID, ("unit:UC func:decode_uop" ))
            UC_FETCH: `UINFO(uinstr_uc0.SIMID, ("unit:UC func:ucrom_uop" ))
        endcase
    end
end
`endif

`ifdef ASSERT
//chk_no_change #(.T(t_uinstr)) cnc ( .clk, .reset, .hold(stall & uinstr_de1.valid & ~br_mispred_rb1), .thing(uinstr_de1) );
`endif

endmodule

`endif // __UCODE_SV

