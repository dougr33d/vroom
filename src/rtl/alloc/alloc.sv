`ifndef __ALLOC_SV
`define __ALLOC_SV

`include "instr.pkg"
`include "instr_decode.pkg"
`include "common.pkg"
`include "vroom_macros.sv"
`include "verif.pkg"

module alloc
   import instr::*, instr_decode::*, common::*, verif::*;
(
    input  logic         clk,
    input  logic         reset,

    input  logic         rob_ready_ra0,
    input  t_uinstr      uinstr_ra0,
    input  t_rename_pkt  rename_ra0,

    output logic         alloc_ready_ra0,
    output logic         alloc_ra0,
    input  t_rob_id      next_robid_ra0,

    output t_rv_reg_addr src_addr_ra0          [NUM_SOURCES-1:0],
    input  logic         rob_src_reg_pdg_ra0   [NUM_SOURCES-1:0],
    input  t_rob_id      rob_src_reg_robid_ra0 [NUM_SOURCES-1:0],

    input  logic         rs_stall_ex_rs0,
    output logic         disp_valid_ex_rs0,
    output t_uinstr_disp disp_ex_rs0
);

localparam RA0 = 0;
localparam RA1 = 1;
localparam NUM_RA_STAGES = 1;

//
// Nets
//

t_uinstr_disp disp_ra0;
t_uinstr_disp disp_ra1;

logic         rs_stall_ports_rs0    [NUM_DISP_PORTS-1:0];
logic         disp_valid_ports_rs0  [NUM_DISP_PORTS-1:0];
t_uinstr_disp disp_ports_rs0        [NUM_DISP_PORTS-1:0];

//
// Logic
//

assign src_addr_ra0[SRC1] = uinstr_ra0.src1.opreg;
assign src_addr_ra0[SRC2] = uinstr_ra0.src2.opreg;

always_comb begin
   disp_ra0.uinstr       = uinstr_ra0;
   disp_ra0.robid        = next_robid_ra0;
   disp_ra0.rename       = rename_ra0;
end

`DFF(disp_ra1, disp_ra0, clk)

// Dispatch port assignments

logic stall_ra1;

assign disp_ports_rs0       [DISP_PORT_EINT] = disp_ra1;
assign disp_valid_ports_rs0 [DISP_PORT_EINT] = disp_ra1.uinstr.valid & ~stall_ra1;

assign disp_ports_rs0       [DISP_PORT_MEM ] = disp_ra1;
assign disp_valid_ports_rs0 [DISP_PORT_MEM ] = 1'b0; // disp_ra1.uinstr.valid;

// Dispatch port demux

assign disp_ex_rs0       = disp_ports_rs0[DISP_PORT_EINT];
assign disp_valid_ex_rs0 = disp_valid_ports_rs0[DISP_PORT_EINT];
assign rs_stall_ports_rs0[DISP_PORT_EINT] = rs_stall_ex_rs0;

// assign disp_mm_rs0       = disp_ports_rs0[DISP_PORT_EINT];
// assign disp_valid_mm_rs0 = disp_valid_ports_rs0[DISP_PORT_EINT];
assign rs_stall_ports_rs0[DISP_PORT_MEM] = 1'b0; //rs_stall_mm_rs0;

// Stall

always_comb begin
   stall_ra1 = 1'b0;
   for (int i=0; i<NUM_DISP_PORTS; i++) begin
      stall_ra1 |= rs_stall_ports_rs0[i];
   end
   stall_ra1 |= ~rob_ready_ra0;
end

assign alloc_ready_ra0 = rob_ready_ra0 & ~stall_ra1;
assign alloc_ra0 = uinstr_ra0.valid & alloc_ready_ra0;

//
// Debug
//

`ifdef SIMULATION
    always @(posedge clk) begin
        for (int p=0; p<NUM_DISP_PORTS; p++) begin
            if (disp_valid_ports_rs0[p]) begin
                `UINFO(disp_ports_rs0[p].uinstr.SIMID, ("unit:RA robid:0x%0x pdst:0x%0x psrc1:0x%0x psrc2:0x%0x %s", 
                    disp_ports_rs0[p].robid, disp_ports_rs0[p].rename.pdst, disp_ports_rs0[p].rename.psrc1, disp_ports_rs0[p].rename.psrc2, 
                    describe_uinstr(disp_ports_rs0[p].uinstr)))
            end
        end
    end
`endif

`ifdef ASSERT
//VASSERT(a_br_mispred, uinstr_rd1.valid & ibr_resvld_ex0, ~ibr_mispred_ex0, "Branch mispredictions not yet supported.")
`endif

endmodule

`endif // __ALLOC_SV

