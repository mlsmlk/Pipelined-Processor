proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/mem_tb/clock
    add wave -position end sim:/mem_tb/alu_in
    add wave -position end sim:/mem_tb/mem_in
    add wave -position end sim:/mem_tb/mem_res
    add wave -position end sim:/mem_tb/alu_res
    add wave -position end sim:/mem_tb/readwrite_flag
    add wave -position end sim:/mem_tb/mem_flag
    add wave -position end sim:/mem_tb/write_data
}

vlib work

;# Compile components if any
vcom data_memory.vhd
vcom data_memory_tb.vhd
vcom write_back.vhd
vcom write_back_tb.vhd
vcom mem_tb.vhd

;# Start simulation
vsim mem_tb

;# Generate a clock with 1ns period
force -deposit clock 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 15ns
run 15ns