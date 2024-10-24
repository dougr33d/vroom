`ifndef __COREDEBUG_SV
`define __COREDEBUG_SV

`include "instr.pkg"
`include "instr_decode.pkg"
`include "mem_common.pkg"
`include "common.pkg"
`include "vroom_macros.sv"
`include "rob_defs.pkg"
`include "verif.pkg"
`include "mem_defs.pkg"
`include "gen_funcs.pkg"

`ifdef SIMULATION

/* verilator lint_off BLKSEQ */
module coredebug
    import instr::*, instr_decode::*, mem_common::*, common::*, rob_defs::*, verif::*, mem_defs::*, gen_funcs::*;
(
    input  logic clk,
    input  logic reset
);

localparam NUM_RS_ENTS = 32;

typedef struct packed {
    logic       valid;
    int         clk;
    time        tick;
    t_instr_pkt instr_fe1;
} t_cd_fetch;

typedef struct packed {
    logic       valid;
    int         clk;
    time        tick;
    t_uinstr    uinstr_de1;
} t_cd_decode;

typedef struct packed {
    logic       valid;
    int         clk;
    time        tick;
    t_uinstr    uinstr_uc0;
} t_cd_ucode;

typedef struct packed {
    logic        valid;
    int          clk;
    time        tick;
    t_rename_pkt rename_rn1;
} t_cd_rename;

typedef struct packed {
    logic         valid;
    int           clk;
    time        tick;
    int           port;
    t_disp_pkt    disp_pkt_ra1;
    logic[$clog2(NUM_RS_ENTS)-1:0] rs_ent_ra1;
} t_cd_alloc;

typedef struct packed {
    logic        valid;
    int          clk;
    time        tick;
    t_iss_pkt    iss_pkt_rs2;
    logic        mm_iss_rs2;
} t_cd_rs;

typedef struct packed {
    logic        valid;
    int          clk;
    time        tick;
    t_prf_wr_pkt iprf_wr_pkt_ro0;
} t_cd_result;

typedef struct packed {
    logic       valid;
    int         clk;
    time        tick;
    t_nuke_pkt  nuke_rb1;
} t_cd_retire;

typedef struct packed {
    logic        valid;
    int          clk;
    time        tick;
    logic        ldq_alloc_rs0;
    logic        stq_alloc_rs0;
    t_ldq_static ldq_alloc_static_rs0;
    t_stq_static stq_alloc_static_rs0;
} t_cd_mem;

typedef struct packed {
    t_simid       SIMID;
    t_cd_fetch    FETCH;
    t_cd_decode   DECODE;
    t_cd_ucode    UCODE;
    t_cd_rename   RENAME;
    t_cd_alloc    ALLOC;
    t_cd_rs       RS;
    t_cd_mem      MEM;
    t_cd_result   RESULT;
    t_cd_retire   RETIRE;
} t_cd_inst;

t_cd_inst  INSTQ[$];

int first_retire_cycle;
int last_retire_cycle;
int num_instrs_retired;

initial begin
    first_retire_cycle = -1;
    last_retire_cycle = -1;
    num_instrs_retired = 0;
end

function automatic string f_describe_src_dst(t_optype optype, t_gpr_id opreg, t_size opsize, t_prf_id psrc, t_rv_reg_data value);
    string opsize_char;
    unique casez(opsize)
        SZ_1B: opsize_char = "B";
        SZ_2B: opsize_char = "H";
        SZ_4B: opsize_char = "W";
        SZ_8B: opsize_char = "D";
        default: opsize_char = "?";
    endcase
    unique casez(optype)
        OP_REG:  f_describe_src_dst = $sformatf("reg %3s value:0x%016h (%s) prf:%s", $sformatf("x%0d",opreg), value, opsize_char, f_describe_prf(psrc));
        OP_IMM:  f_describe_src_dst = $sformatf("imm     value:0x%016h",            value);
        OP_ZERO: f_describe_src_dst = $sformatf("zero    value:0x%016h",            0);
        OP_INVD: f_describe_src_dst = $sformatf("invalid",                      );
        OP_MEM:  f_describe_src_dst = $sformatf("mem (%s)", opsize_char);
        default: f_describe_src_dst = $sformatf("?????");
    endcase
endfunction

function automatic void cd_print_mem_rec(t_cd_inst rec);
    if (rec.MEM.ldq_alloc_rs0) begin
        //`PMSG(CDBG, ($sformatf("Ld VA:%08h DATA:%016h", rec.MEM.ldq_alloc_static_mm0.vaddr, rec.RESULT.iprf_wr_pkt_ro0.data)))
    end else begin
        //`PMSG(CDBG, ($sformatf("St VA:%08h", rec.MEM.stq_alloc_static_mm0.vaddr)))
    end
endfunction

task cd_print_rec(t_cd_inst rec);
    `PMSG(CDBG, ("---------------------[ %4d @%-4t ]---------------------", top.cclk_count, $time()));
    `PMSG(CDBG, (describe_uinstr(rec.UCODE.uinstr_uc0)))
    `PMSG(CDBG, ("PC 0x%04h %sROBID 0x%0h RS %d -- %s", rec.UCODE.uinstr_uc0.SIMID.pc,
        (rec.UCODE.uinstr_uc0.from_ucrom ? $sformatf("ROMADR 0x%03h ", rec.UCODE.uinstr_uc0.rom_addr) : ""),
        rec.RENAME.rename_rn1.robid, rec.ALLOC.rs_ent_ra1, format_simid(rec.SIMID)))
    `PMSG(CDBG, (""))
    if (rec.RS.mm_iss_rs2) begin
        cd_print_mem_rec(rec);
        `PMSG(CDBG, (""))
    end
    `PMSG(CDBG, ($sformatf(" src1 %s", f_describe_src_dst(rec.RS.iss_pkt_rs2.uinstr.src1.optype, rec.RS.iss_pkt_rs2.uinstr.src1.opreg, rec.RS.iss_pkt_rs2.uinstr.src1.opsize, rec.RENAME.rename_rn1.psrc1, rec.RS.iss_pkt_rs2.src1_val))))
    `PMSG(CDBG, ($sformatf(" src2 %s", f_describe_src_dst(rec.RS.iss_pkt_rs2.uinstr.src2.optype, rec.RS.iss_pkt_rs2.uinstr.src2.opreg, rec.RS.iss_pkt_rs2.uinstr.src2.opsize, rec.RENAME.rename_rn1.psrc2, rec.RS.iss_pkt_rs2.src2_val))))
    `PMSG(CDBG, ($sformatf("  dst %s", f_describe_src_dst(rec.RS.iss_pkt_rs2.uinstr.dst .optype, rec.RS.iss_pkt_rs2.uinstr.dst .opreg, rec.RS.iss_pkt_rs2.uinstr.dst .opsize, rec.RENAME.rename_rn1.pdst , rec.RESULT.iprf_wr_pkt_ro0.data))))
    `PMSG(CDBG, (""))
    if (rec.FETCH.valid)
        `PMSG(CDBG, ("    Fetch  -> Decode @[%-d] %-d", rec.FETCH.tick, rec.FETCH.clk))
    if (rec.DECODE.valid)
        `PMSG(CDBG, ("    Decode -> Ucode  @[%-d] %-d", rec.DECODE.tick, rec.DECODE.clk))
    `PMSG(CDBG, ("    Ucode  -> Rename @[%-d] %-d", rec.UCODE.tick, rec.UCODE.clk))
    `PMSG(CDBG, ("    Rename -> Alloc  @[%-d] %-d", rec.RENAME.tick, rec.RENAME.clk))
    `PMSG(CDBG, ("    Alloc  -> RS.%0d   @[%-d] %-d", rec.ALLOC.port, rec.ALLOC.tick, rec.ALLOC.clk))
    `PMSG(CDBG, ("              Result @[%-d] %-d", rec.RESULT.tick, rec.RESULT.clk))
    `PMSG(CDBG, ("              Retire @[%-d] %-d  %s", rec.RETIRE.tick, rec.RETIRE.clk, rec.RETIRE.nuke_rb1.valid ? "NUKE!!!" : ""))
    `PMSG(CDBG, (""))
    if (rec.UCODE.uinstr_uc0.dst.optype == OP_REG) begin
        `PMSG(CDBG, ("Register Updates"))
        `PMSG(CDBG, ("  GPR %5s := 0x%08h (prf %s -> %s)", f_describe_gpr_addr(rec.UCODE.uinstr_uc0.dst.opreg), rec.RESULT.iprf_wr_pkt_ro0.data, f_describe_prf(rec.RENAME.rename_rn1.pdst_old), f_describe_prf(rec.RENAME.rename_rn1.pdst)))
        `PMSG(CDBG, (""))
        if(rec.RESULT.iprf_wr_pkt_ro0.data == 64'h666) begin
            `INFO(("Saw 666; dying!"))
            eot();
            $error("mark of the beast detected");
        end
    end
    if(rec.DECODE.uinstr_de1.uop == U_EBREAK) begin
        `INFO(("Saw EBREAK... goodbye, folks!"))
        eot();
        $finish();
    end
endtask

task cd_print_rec_retlog(t_cd_inst rec);
    string reg_upd;
    if (rec.UCODE.uinstr_uc0.dst.optype == OP_REG) begin
        reg_upd = $sformatf("reg_wr:1 reg:%0d reg_data:%0h", rec.UCODE.uinstr_uc0.dst.opreg, rec.RESULT.iprf_wr_pkt_ro0.data);
    end else begin
        reg_upd = $sformatf("reg_wr:0");
    end
    `PMSG(RETLOG, ("time:%0t cclk:%0d pc:%0h eom:%0d %s %s",
        $time(),
        top.cclk_count,
        rec.UCODE.uinstr_uc0.SIMID.pc,
        rec.UCODE.uinstr_uc0.eom,
        reg_upd,
        format_simid(rec.SIMID)
        ));
endtask


task cd_fetch();
    t_cd_inst new_inst;
    new_inst = '0;

    new_inst.SIMID = top.core.instr_fe1.SIMID;

    new_inst.FETCH.valid     = 1'b1;
    new_inst.FETCH.clk       = top.cclk_count;
    new_inst.FETCH.tick      = $time();
    new_inst.FETCH.instr_fe1 = top.core.instr_fe1;

    INSTQ.push_back(new_inst);
endtask

function automatic int f_instq_find_match(t_simid THIS_SIMID);
    f_instq_find_match = -1;
    for (int i=0; i<INSTQ.size(); i++) begin
        if (INSTQ[i].SIMID.lid == THIS_SIMID.lid) begin
            if (f_instq_find_match != -1) begin
                $error("Found multiple instq matches! %s", format_simid(THIS_SIMID));
            end
            f_instq_find_match = i;
        end
    end
endfunction

`define CHK_INSTQ_MATCH(VAL,NAME,THIS_SIMID) \
    if (VAL == -1) $error("Died in %s trying to find INSTQ match! %s", `"NAME`", format_simid(THIS_SIMID));

task cd_decode();
    int i; i = f_instq_find_match(top.core.uinstr_de1.SIMID);
    `CHK_INSTQ_MATCH(i,cd_decode,top.core.uinstr_de1.SIMID)

    if (INSTQ[i].DECODE.valid) begin
        $error("Trying to add a decode to a record that is already valid! %s", format_simid(top.core.uinstr_de1.SIMID));
    end
    INSTQ[i].DECODE.valid = 1'b1;
    INSTQ[i].DECODE.clk = top.cclk_count;
    INSTQ[i].DECODE.tick= $time();
    INSTQ[i].DECODE.uinstr_de1 = top.core.uinstr_de1;
endtask

task cd_ucode();
    int i;
    if (top.core.ucode.ucrom_active_uc0) begin
        t_cd_inst new_inst;
        new_inst = '0;
        new_inst.SIMID = top.core.uinstr_uc0.SIMID;
        INSTQ.push_back(new_inst);
    end

    i = f_instq_find_match(top.core.uinstr_uc0.SIMID);
    `CHK_INSTQ_MATCH(i,cd_ucode,top.core.uinstr_uc0.SIMID)

    if (INSTQ[i].UCODE.valid) begin
        $error("Trying to add a decode to a record that is already valid! %s", format_simid(top.core.uinstr_uc0.SIMID));
    end
    INSTQ[i].UCODE.valid = 1'b1;
    INSTQ[i].UCODE.clk = top.cclk_count;
    INSTQ[i].UCODE.tick= $time();
    INSTQ[i].UCODE.uinstr_uc0 = top.core.uinstr_uc0;
endtask

task cd_rename();
    int i; i = f_instq_find_match(top.core.uinstr_rn1.SIMID);
    `CHK_INSTQ_MATCH(i,cd_rename,top.core.uinstr_rn1.SIMID)

    if (INSTQ[i].RENAME.valid) begin
        $error("Trying to add a rename to a record that is already valid! %s", format_simid(top.core.uinstr_rn1.SIMID));
    end
    INSTQ[i].RENAME.valid = 1'b1;
    INSTQ[i].RENAME.clk = top.cclk_count;
    INSTQ[i].RENAME.tick= $time();
    INSTQ[i].RENAME.rename_rn1 = top.core.rename_rn1;
endtask

task cd_alloc();
    int i; i = f_instq_find_match(top.core.alloc.disp_pkt_rs0.uinstr.SIMID);
    `CHK_INSTQ_MATCH(i,cd_alloc,top.core.alloc.disp_pkt_rs0.uinstr.SIMID)

    if (INSTQ[i].ALLOC.valid) begin
        $error("Trying to add an alloc to a record that is already valid!");
    end
    INSTQ[i].ALLOC.valid = 1'b1;
    INSTQ[i].ALLOC.clk = top.cclk_count;
    INSTQ[i].ALLOC.tick= $time();
    INSTQ[i].ALLOC.disp_pkt_ra1 = top.core.alloc.disp_pkt_rs0;
    INSTQ[i].ALLOC.rs_ent_ra1   = top.core.rs.q_alloc_id_rs0;
endtask

task cd_rs();
    int i; i = f_instq_find_match(top.core.rs.iss_pkt_rs2.uinstr.SIMID);
    `CHK_INSTQ_MATCH(i,cd_rs,top.core.rs.iss_pkt_rs2.uinstr.SIMID)

    if (INSTQ[i].RS.valid) begin
        $error("Trying to add a decode to a record that is already valid! %s", format_simid(top.core.rs.iss_pkt_rs2.uinstr.SIMID));
    end
    INSTQ[i].RS.valid = 1'b1;
    INSTQ[i].RS.clk = top.cclk_count;
    INSTQ[i].RS.tick= $time();
    INSTQ[i].RS.iss_pkt_rs2 = top.core.rs.iss_pkt_rs2;
    INSTQ[i].RS.mm_iss_rs2 = top.core.rs.mm_iss_rs2;
endtask

task cd_mem_ld();
    int i; i = f_instq_find_match(top.core.mem.loadq.q_alloc_static_rs0.SIMID);
    `CHK_INSTQ_MATCH(i,cd_mem_ld,top.core.mem.loadq.q_alloc_static_rs0.SIMID)
    if (INSTQ[i].MEM.valid) begin
        $error("Trying to add mem to a record that is already valid!");
    end
    INSTQ[i].MEM.ldq_alloc_rs0 = top.core.mem.loadq.q_alloc_rs0;
    INSTQ[i].MEM.ldq_alloc_static_rs0 = top.core.mem.loadq.q_alloc_static_rs0;
    INSTQ[i].MEM.stq_alloc_rs0 = '0;
    INSTQ[i].MEM.stq_alloc_static_rs0 = '0;
endtask

task cd_mem_st();
    int i; i = f_instq_find_match(top.core.mem.storeq.q_alloc_static_rs0.SIMID);
    `CHK_INSTQ_MATCH(i,cd_mem_st,top.core.mem.storeq.q_alloc_static_rs0.SIMID)
    if (INSTQ[i].MEM.valid) begin
        $error("Trying to add mem to a record that is already valid!");
    end
    INSTQ[i].MEM.ldq_alloc_rs0 = '0;
    INSTQ[i].MEM.ldq_alloc_static_rs0 = '0;
    INSTQ[i].MEM.stq_alloc_rs0 = top.core.mem.storeq.q_alloc_rs0;
    INSTQ[i].MEM.stq_alloc_static_rs0 = top.core.mem.storeq.q_alloc_static_rs0;
endtask

task cd_result_mm();
    int i; i = f_instq_find_match(top.core.iprf_wr_pkt_mm5.SIMID);
    `CHK_INSTQ_MATCH(i,cd_result_mm,top.core.iprf_wr_pkt_mm5.SIMID)

    if (INSTQ[i].RESULT.valid) begin
        $error("Trying to add a result to a record that is already valid!");
    end
    INSTQ[i].RESULT.valid = 1'b1;
    INSTQ[i].RESULT.clk = top.cclk_count;
    INSTQ[i].RESULT.tick= $time();
    INSTQ[i].RESULT.iprf_wr_pkt_ro0 = top.core.iprf_wr_pkt_mm5;
endtask

task cd_result_eint();
    int i; i = f_instq_find_match(top.core.iprf_wr_pkt_ex1.SIMID);
    `CHK_INSTQ_MATCH(i,cd_result_eint,top.core.iprf_wr_pkt_ex1.SIMID)

    if (INSTQ[i].RESULT.valid) begin
        $error("Trying to add a result to a record that is already valid!");
    end
    INSTQ[i].RESULT.valid = 1'b1;
    INSTQ[i].RESULT.clk = top.cclk_count;
    INSTQ[i].RESULT.tick= $time();
    INSTQ[i].RESULT.iprf_wr_pkt_ro0 = top.core.iprf_wr_pkt_ex1;
endtask

task croak_instq(int instq_index);
    `PMSG(CDBG, ("ERROR INSTQ[%d] %s", instq_index, format_simid(INSTQ[instq_index].SIMID)))
endtask

task cd_retire();
    int i; i = f_instq_find_match(top.core.rob.head_entry.s.uinstr.SIMID);
    `CHK_INSTQ_MATCH(i,cd_retire,top.core.rob.head_entry.s.uinstr.SIMID)

    if (INSTQ[i].RETIRE.valid) begin
        $error("Trying to retire a record that is already retired!");
    end
    if (!INSTQ[i].RESULT.valid) begin
        croak_instq(i);
        `PMSG(CDBG, ("ERROR ROB %0h %s", top.core.rob.head_id, format_simid(top.core.rob.head_entry.s.uinstr.SIMID)))
        $error("Trying to retire a record with no result!");
    end
    INSTQ[i].RETIRE.valid = 1'b1;
    INSTQ[i].RETIRE.clk = top.cclk_count;
    INSTQ[i].RETIRE.tick= $time();
    INSTQ[i].RETIRE.nuke_rb1 = core.rob.nuke_rb1;
    cd_print_rec(INSTQ[i]);
    cd_print_rec_retlog(INSTQ[i]);
    if (INSTQ[i].RETIRE.nuke_rb1.valid) begin
        INSTQ.delete();
    end else begin
        INSTQ.delete(i);
    end

    if (first_retire_cycle == -1) begin
        first_retire_cycle = top.cclk_count;
    end
    last_retire_cycle = top.cclk_count;
    num_instrs_retired += 1;
endtask

always_ff @(posedge clk) begin
    if (core.valid_fe1 & core.decode_ready_de0) cd_fetch();
    if (core.valid_de1 & core.ucode_ready_uc0) cd_decode();
    if (core.valid_uc0 & core.rename_ready_rn0) cd_ucode();
    if (core.valid_rn1 & core.alloc_ready_ra0) cd_rename();

    if (core.alloc.disp_valid_rs0) cd_alloc();

    if (core.rs.iss_rs2  ) cd_rs();
    if (core.mem.loadq.q_alloc_rs0) cd_mem_ld();
    if (core.mem.storeq.q_alloc_rs0) cd_mem_st();
    if (core.exe.complete_ex1.valid) cd_result_eint();
    if (core.mem.complete_mm5.valid) cd_result_mm();

    if (core.rob.q_retire_rb1) cd_retire();
end

///////////////////
// Regdump ////////
///////////////////

function automatic t_prf_id f_get_gpr_prfid(t_gpr_id gpr);
    return {core.rename.iprf.prf_type, core.rename.iprf.MAP[gpr]};
endfunction

function automatic t_rv_reg_data f_get_gpr_data(t_gpr_id gpr);
    t_prf_id prfid = f_get_gpr_prfid(gpr);
    return core.rename.iprf.PRF[prfid.idx];
endfunction

function automatic string f_describe_gpr_full(t_gpr_id gpr, logic hide_zeros);
    t_prf_id prf_id = f_get_gpr_prfid(gpr);
    t_rv_reg_data data = f_get_gpr_data(gpr);

    if (gpr == 0)
        return "";
    return $sformatf("%s:%s (%9s)", f_describe_gpr_addr(gpr), f_describe_gpr_data(data, hide_zeros), f_describe_prf(prf_id));
endfunction

function automatic void dump_gprs();
    `PMSG(CDBG, ("GPR State"))
    `PMSG(CDBG, ("---------"))
    for (int g=0; g<(IPRF_NUM_REGS/4); g++) begin
        `PMSG(CDBG, ("%36s  %36s  %36s  %36s",
            f_describe_gpr_full(t_gpr_id'(g + (IPRF_NUM_REGS/4)*0), 1'b1),
            f_describe_gpr_full(t_gpr_id'(g + (IPRF_NUM_REGS/4)*1), 1'b1),
            f_describe_gpr_full(t_gpr_id'(g + (IPRF_NUM_REGS/4)*2), 1'b1),
            f_describe_gpr_full(t_gpr_id'(g + (IPRF_NUM_REGS/4)*3), 1'b1)))
    end
endfunction

///////////////////
// EOT stuff //////
///////////////////

task cd_print_rec_unretired(t_cd_inst rec);
    `PMSG(CDBG, ("-------------------------------------------------------"));
    if (rec.ALLOC.valid) begin
        `PMSG(CDBG, (describe_uinstr(rec.DECODE.uinstr_de1)))
        `PMSG(CDBG, ("PC 0x%04h ROBID 0x%0h -- %s", rec.FETCH.instr_fe1.SIMID.pc, rec.RENAME.rename_rn1.robid, format_simid(rec.FETCH.instr_fe1.SIMID)))
    end else if (rec.DECODE.valid) begin
        `PMSG(CDBG, (describe_uinstr(rec.DECODE.uinstr_de1)))
        `PMSG(CDBG, ("PC 0x%04h -- %s", rec.FETCH.instr_fe1.SIMID.pc, format_simid(rec.FETCH.instr_fe1.SIMID)))
    end else begin
        `PMSG(CDBG, (describe_instr(rec.FETCH.instr_fe1)))
        `PMSG(CDBG, ("PC 0x%04h -- %s", rec.FETCH.instr_fe1.SIMID.pc, format_simid(rec.FETCH.instr_fe1.SIMID)))
    end
endtask

task cd_print_all_unretired();
    t_cd_inst rec;
    for (int i=0; i<INSTQ.size(); i++) begin
        rec = INSTQ[i];
        if (!rec.RETIRE.valid) begin
            cd_print_rec_unretired(rec);
        end
    end
endtask

task eot();
    real ipc;
    real min_ipc;
    `PMSG(CDBG, ("Starting EOT dumps"))
    `PMSG(CDBG, (""))
    cd_print_all_unretired();
    `PMSG(CDBG, (""))
    dump_gprs();
    `PMSG(CDBG, (""))
    ipc = (1.0*num_instrs_retired) / (last_retire_cycle - first_retire_cycle);
    `PMSG(CDBG, ("first_ret:%0d last_ret:%0d IPC:%0f", first_retire_cycle, last_retire_cycle, ipc));

    if ($value$plusargs("min_ipc:%f", min_ipc)) begin
        if (min_ipc > ipc) begin
            $error("real IPC %0f < min IPC %0f", ipc, min_ipc);
        end
    end
endtask

///////////////////
// Hang debug /////
///////////////////

localparam MAX_ROB_TIMEOUT = 200;
task hang_detected();
    eot();
    $error("HANG detected!");
    $finish();
endtask

always_ff @(posedge clk) begin
    if ((top.cclk_count - last_retire_cycle) == MAX_ROB_TIMEOUT) begin
        hang_detected();
    end
end

endmodule
/* verilator lint_on BLKSEQ */

`endif

`endif // __COREDEBUG_SV
