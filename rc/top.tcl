source "rc/common.tcl"

# Core signals
set sigs      [list clk reset]
set sigs      [prefixAll "${CORE}." $sigs]
addSignalGroup "Core" $sigs
puts $sigs

proc addGroupDict {grpd {pfx ""}} {
    gtkwave::/Edit/UnHighlight_All

    # then children
    if {[dict exists $grpd children]} {
        set children [dict get $grpd children]
        foreach child $children {
            set my_pfx [dict get $grpd prefix]
            addGroupDict $child "${pfx}${my_pfx}"
        }
    }

    # first add all signals
    set signals [dict get $grpd signals]
    set pfx_signals [prefixAll [dict get $grpd prefix] $signals]
    if {[dict exists $grpd signals]} {
        gtkwave::addSignalsFromList $pfx_signals 
    }

    #gtkwave::/Edit/UnHighlight_All

    # then iterate over signals again, highlighting
    if {[dict exists $grpd signals]} {
        gtkwave::highlightSignalsFromList $pfx_signals
    }

    # ditto groups
    if {[dict exists $grpd children]} {
        foreach child [dict get $grpd children] {
            gtkwave::/Edit/Highlight_Regexp [dict get $child group_name]
        }
    }

    gtkwave::/Edit/Create_Group [dict get $grpd group_name]
}

proc makeNode {name pfx sigs kids} {
    set grp [dict create]
    dict set grp prefix $pfx
    dict set grp group_name $name
    dict set grp signals $sigs
    dict set grp children $kids
    return $grp
}

proc makeParent {name pfx kids} {
    return [makeNode $name "" [list] $kids]
}

proc makeLeaf {name pfx sigs} {
    return [makeNode $name $pfx $sigs [list]]
}

set sigs [list br_mispred_rb1 br_tgt_rb1 stall valid_fe1 instr_fe1.instr.opcode instr_fe1.pc f__instr_fe1]
set fe_ctl [makeLeaf "FE CTL" "${FE_CTL}." $sigs]

set sigs [list state PC]
set fe_misc [makeLeaf "FE MISC" "${FE_CTL}." $sigs]

set sigs [list fb_ic_req_nnn.valid fb_ic_req_nnn.addr]
set fb_ic_req [makeLeaf "FB2IC Req" "${FE_BUF}." $sigs]

set fetch [makeParent "FE" "" [list $fe_ctl $fe_misc $fb_ic_req]]
addGroupDict $fetch

# Decode signals
set uinstr_fields [prefixAll "uinstr_de1." [list valid SIMID.fid uop funct imm64 opcode]]

set de_ctl [makeLeaf "DE CTL" "" [list valid_fe1]]
set src1   [makeLeaf "DE Src1" "uinstr_de1.src1." $T_OPND]
set src2   [makeLeaf "DE Src2" "uinstr_de1.src2." $T_OPND]
set dst    [makeLeaf "DE Dst"  "uinstr_de1.dst."  $T_OPND]

addGroupDict [makeNode "Decode" "${DECODE}." [list] [list $de_ctl $src1 $src2 $dst]]

# RegRd  signals
set uinstr_fields [makeLeaf "RD Uop" "uinstr_rd1." [list valid SIMID.fid uop funct imm64 opcode]]
set src1          [makeLeaf "RD Src1" "uinstr_rd1.src1." $T_OPND]
set src2          [makeLeaf "RD Src2" "uinstr_rd1.src2." $T_OPND]
set dst           [makeLeaf "RD Dst"  "uinstr_rd1.dst."  $T_OPND]
addGroupDict [makeNode "RD" "${REGRD}." [list] [list $uinstr_fields $dst $src1 $src2]]

# EXE  signals
set uinstr_fields [makeLeaf "EXE Uop"  "uinstr_ex1." [list valid SIMID.fid uop funct imm64 opcode]]
set src1          [makeLeaf "EXE Src1" "uinstr_ex1.src1." $T_OPND]
set src2          [makeLeaf "EXE Src2" "uinstr_ex1.src2." $T_OPND]
set dst           [makeLeaf "EXE Dst"  "uinstr_ex1.dst."  $T_OPND]
addGroupDict [makeNode "EX" "${EXE}." [list] [list $uinstr_fields $src1 $src2 $dst]]

# Mem  signals
set uinstr_fields [makeLeaf "MEM Uop" "uinstr_mm1." [list valid SIMID.fid uop funct imm64 opcode]]
set src1          [makeLeaf "MEM Src1" "uinstr_mm1.src1." $T_OPND]
set src2          [makeLeaf "MEM Src2" "uinstr_mm1.src2." $T_OPND]
set dst           [makeLeaf "MEM Dst"  "uinstr_mm1.dst."  $T_OPND]
addGroupDict [makeNode "MM" "${MEM}." [list] [list $uinstr_fields $src1 $src2 $dst]]
return

# Retire signals
set uinstr_fields [prefixAll "uinstr_rb0." [list valid SIMID.fid uop funct imm64 opcode]]
set src1          [prefixAll "uinstr_rb0.src1." $T_OPND]
set src2          [prefixAll "uinstr_rb0.src2." $T_OPND]
set dst           [prefixAll "uinstr_rb0.dst."  $T_OPND]
set regwr         [list wren_rb0 wraddr_rb0 wrdata_rb0]
set sigs      [list {*}$uinstr_fields {*}$dst {*}$src1 {*}$src2 {*}$regwr]
set rb_sigs   [prefixAll "${RETIRE}." $sigs]
addSignalGroup "RB" $rb_sigs 0

# Scoreboard
set sigs      [list stall]
set sb_sigs   [prefixAll "${SCORE}." $sigs]
addSignalGroup "Scoreboard" $sb_sigs 1

# Regfile
set sigs      [list]
for {set i 0} {$i < 32} {incr i} {
    lappend sigs "REGS\[$i\]"
}
set gpr_sigs  [prefixAll "${GPRS}." $sigs]
addSignalGroup "GPRs" $gpr_sigs 1

