proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
	add wave -position end  sim:/fetch_tb/dut/clock
	add wave -position end  sim:/fetch_tb/dut/reset
	add wave -position end  sim:/fetch_tb/dut/jump_address
	add wave -position end  sim:/fetch_tb/dut/jump_flag
	add wave -position end  sim:/fetch_tb/dut/stall_pipeline
	add wave -position end  sim:/fetch_tb/dut/instruction
	add wave -position end  sim:/fetch_tb/dut/program_counter_out
	add wave -position end  sim:/fetch_tb/dut/reset_out
	add wave -position end  sim:/fetch_tb/dut/program_counter
	add wave -position end  sim:/fetch_tb/dut/reset_to_decode
	add wave -position end  sim:/fetch_tb/dut/im_readdata
}

vlib work

;# Compile components if any
vcom instruction_memory.vhd
vcom fetch.vhd
vcom fetch_tb.vhd

;# Start simulation
vsim fetch_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 50 ns
run 10ns