`ifndef __RETIRE_SV
`define __RETIRE_SV

`include "instr.pkg"
`include "vroom_macros.sv"
`include "common.pkg"
`include "rob_defs.pkg"

module retire
    import instr::*, instr_decode::*, verif::*, common::*, rob_defs::*;
(
    input  logic             clk,
    input  logic             reset,

    output logic             rob_ready_ra0,
    input  logic             alloc_ra0,
    input  t_uinstr          uinstr_ra0,
    input  t_rename_pkt      rename_ra0,

    input  t_gpr_id          src_addr_ra0          [NUM_SOURCES-1:0],
    output logic             rob_src_reg_pdg_ra0   [NUM_SOURCES-1:0],
    output t_rob_id          rob_src_reg_robid_ra0 [NUM_SOURCES-1:0],

    input  logic             ro_valid_rb0,
    input  rob_defs::t_rob_result
                             ro_result_rb0,

    output t_rob_id          next_robid_ra0,

    output logic             reclaim_prf_rb1,
    output t_prf_id          reclaim_prf_id_rb1,

    output logic             br_mispred_rb1,
    output t_paddr           br_tgt_rb1
);

//
// Nets
//

//
// Logic
//

rob rob (
    .clk,
    .reset,
    .rob_ready_ra0,
    .uinstr_ra0,
    .rename_ra0,
    .alloc_ra0,

    .src_addr_ra0,
    .rob_src_reg_pdg_ra0,
    .rob_src_reg_robid_ra0,

    .ro_valid_rb0,
    .ro_result_rb0,

    .reclaim_prf_rb1,
    .reclaim_prf_id_rb1,

    .next_robid_ra0,

    .uinstr_rb1 ( ),

    .br_mispred_rb1,
    .br_tgt_rb1
);

//
// Debug
//

`ifdef ASSERT
// chk_always_increment #(.T(int)) fid_counting_up (
//     .clk,
//     .reset,
//     .valid ( uinstr_mm1.valid     ),
//     .count ( uinstr_mm1.SIMID.fid )
// );
`endif

endmodule

`endif // __RETIRE_SV

