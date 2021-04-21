proc AddWaves {} {
    ;# Add important waves to the Wave window
    add wave -position end  sim:/pipelined_processor_tb/proc/clock
    add wave -position end  sim:/pipelined_processor_tb/proc/reset
    add wave -position end  sim:/pipelined_processor_tb/proc/write_to_file
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/reset
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/jump_address
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/jump_flag
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/stall_pipeline
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/instruction
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/program_counter_out
	add wave -position end  sim:/pipelined_processor_tb/proc/instf/reset_out
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/write_reg_file
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/w_regdata
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/f_stall
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_insttype
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_opcode
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_readdata1
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_readdata2
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_imm
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_forward_ex
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_forwardop_ex
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_forward_mem
	add wave -position end  sim:/pipelined_processor_tb/proc/dec/e_forwardop_mem
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/m_forward_data
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/alu_result
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/writedata
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/readwrite_flag
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/branch_taken
	add wave -position end  sim:/pipelined_processor_tb/proc/ex/branch_target_addr
	add wave -position end  sim:/pipelined_processor_tb/proc/mem/mem_res
	add wave -position end  sim:/pipelined_processor_tb/proc/mem/mem_flag
	add wave -position end  sim:/pipelined_processor_tb/proc/mem/alu_res
	add wave -position end  sim:/pipelined_processor_tb/proc/wb/write_data
}

vlib work

;# Compile components
vcom instruction_memory.vhd
vcom fetch.vhd
vcom Decode.vhd
vcom Execute.vhd
vcom data_memory.vhd
vcom write_back.vhd
vcom Pipelined_Processor.vhd
vcom Pipelined_Processor_tb.vhd

;# Start simulation
vsim Pipelined_Processor_tb

;# Generate a 1 ns period clock
force -deposit clock 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 10090 ns
run 10090ns
