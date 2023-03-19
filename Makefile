INC_DIR   := src/rtl/include/
SRC_DIR   := src/rtl/
LIB_DIR   := src/rtl/lib/

INC_FILES := $(shell find $(INC_DIR) -name '*.sv')
LIB_FILES := $(shell find $(LIB_DIR) -name '*.sv')
SRC_FILES := src/rtl/top.sv \
             src/rtl/core.sv \
	     src/rtl/decode.sv 

IVERILOG  := iverilog -g2012

.PHONY: run
run: Vtop
	obj_dir/Vtop

Vtop: verilated
	make -C obj_dir -f Vtop.mk Vtop

.PHONY: verilated
verilated: $(SRC_FILES) $(LIB_FILES) 
	verilator  --trace-fst --trace-structs --trace-params --exe tb_top.cpp --cc -y $(LIB_DIR) -I$(INC_DIR) src/rtl/top.sv $(SRC_FILES)

.PHONY: clean
clean:
	rm -rf obj_dir/
	rm -f waves.fst

#sim: $(SRC_FILES) $(LIB_FILES)
#	$(IVERILOG) -I $(INC_DIR) -y $(LIB_DIR) -f src/rtl.f -o $@
#
#.PHONY: run
#run: sim
#	./sim
#
#.PHONY: clean
#clean:
#	rm -f sim
