`ifndef __ROB_ENTRY_SV
`define __ROB_ENTRY_SV

`include "instr.pkg"
`include "vroom_macros.sv"
`include "common.pkg"
`include "rob_defs.pkg"

module rob_entry
    import instr::*, instr_decode::*, verif::*, common::*, rob_defs::*;
(
    input  logic                  clk,
    input  logic                  reset,
    input  t_rob_id               robid,
    input  t_rob_id               head_id,

    input  rob_defs::t_rob_ent_static
                                  q_alloc_s_rn0,
    input  logic                  e_alloc_rn0,

    input  logic                  rob_wr_rn1,
    input  t_rename_pkt           rename_rn1,

    input  t_rob_complete_pkt     ro_complete_rb0       [NUM_COMPLETES-1:0],

    input  logic                  q_flush_now_rb1,

    output logic                  e_valid,
    output rob_defs::t_rob_ent    rob_entry,
    input  logic                  e_retire_rb1
);

//
// FSM
//

typedef enum logic[1:0] {
   RBE_IDLE,
   RBE_PDG,
   RBE_READY
} t_rob_ent_fsm;
t_rob_ent_fsm fsm, fsm_nxt;

//
// Nets
//

logic         e_wb_valid_rb0;

// Flushes
logic         e_flush_needed;
logic         e_flush_needed_rb0;
logic         e_flush_now_rb1;

//
// FSM
//

assign e_flush_now_rb1 = q_flush_now_rb1 & (head_id.idx != robid.idx);

always_comb begin
   fsm_nxt = fsm;
   if (reset) begin
      fsm_nxt = RBE_IDLE;
   end else begin
      unique casez (fsm)
         RBE_IDLE:    if ( e_alloc_rn0     ) fsm_nxt = RBE_PDG;
         RBE_PDG:     if ( q_flush_now_rb1 ) fsm_nxt = RBE_IDLE;
                 else if ( e_wb_valid_rb0  ) fsm_nxt = RBE_READY;
         RBE_READY:   if ( q_flush_now_rb1 ) fsm_nxt = RBE_IDLE;
                 else if ( e_retire_rb1    ) fsm_nxt = RBE_IDLE;
      endcase
   end
end
`DFF(fsm, fsm_nxt, clk)

assign e_valid = (fsm != RBE_IDLE);

//
// Logic
//

t_rob_complete_pkt e_ro_complete_rb0;
always_comb begin
    e_ro_complete_rb0 = '0;
    for (int i=0; i<NUM_COMPLETES; i++) begin
        e_ro_complete_rb0 |= (ro_complete_rb0[i].valid & ro_complete_rb0[i].robid.idx == robid.idx) ? ro_complete_rb0[i] : '0;
    end
end

assign e_wb_valid_rb0 = e_ro_complete_rb0.valid & e_ro_complete_rb0.robid.idx == robid.idx;

//
// Dynamic state
//

`DFF(e_flush_needed, ~e_alloc_rn0 & (e_flush_needed | e_wb_valid_rb0 & e_ro_complete_rb0.mispred), clk)

t_prf_id e_pdst_old;
`DFF_EN(e_pdst_old, rename_rn1.pdst_old, clk, rob_wr_rn1 & rename_rn1.robid.idx == robid.idx)

assign rob_entry.d.ready        = fsm == RBE_READY;
assign rob_entry.d.flush_needed = e_flush_needed;
assign rob_entry.d.pdst_old     = e_pdst_old;

//
// Static state
//

t_rob_ent_static s;
`DFF_EN(s, q_alloc_s_rn0, clk, e_alloc_rn0)
assign rob_entry.s = s;

//
// Debug
//

`ifdef SIMULATION

`endif

`ifdef ASSERT

`endif

endmodule

`endif // __ROB_ENTRY_SV


