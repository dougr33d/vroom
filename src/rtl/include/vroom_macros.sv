`ifndef __VROOM_MACROS_SV
`define __VROOM_MACROS_SV 

`define DFF(Q,D,clk) \
    always_ff @(posedge clk) Q <= D;

`define DFF_EN(Q,D,clk,en) \
    always_ff @(posedge clk) if(en) Q <= D;

`define MKFLAT(sig) \
    logic[$bits(sig)-1:0] f__``sig``; assign f__``sig`` = sig;

`define MKPIPE(tp, sigx, fr, to) \
    tp sigx [``to``:``fr``]; \
    for (genvar stg=``fr``+1; stg<=``to``; stg++) `DFF(``sigx``[stg], ``sigx``[stg-1], clk)

`define MKPIPE_INIT(tp, sigx, sig0, fr, to) \
    `MKPIPE(tp,sigx,fr,to) \
    always_comb sigx[fr]=sig0; 

`define PMSG(tag, msg) \
    $display("@[%-d] %-d tag: %s", $time(), top.cclk_count, $sformatf msg);

`define RETLOG(msg)   `PMSG(RET,  msg)
`define INFO(msg)     `PMSG(INFO, msg)
`define MEMLOG(msg)   `PMSG(MEM,  msg)
`define GENLOG(pfx, msg)   `PMSG(pfx,  msg)

`ifdef DEBUGON
    `define DEBUG(msg) \
        `PMSG(D, msg)
`else
    `define DEBUG(msg) 
`endif

`define VASSERT(name, antecedent, consequent, msg) \
    name: assert property (@(posedge clk) disable iff(reset) (antecedent) |-> (consequent)) else $error(msg);

`define CHK_ONEHOT(name, valid, bits) \
    name: assert property (@(posedge clk) disable iff(reset) (valid) |-> $onehot(bits)) else $error($sformatf("ONEHOT check failed! %b",bits));

`endif // __VROOM_MACROS_SV 
