proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/data_memory_tb/clock
    add wave -position end sim:/data_memory_tb/alu_in
    add wave -position end sim:/data_memory_tb/mem_in
    add wave -position end sim:/data_memory_tb/mem_res
    add wave -position end sim:/data_memory_tb/alu_res
    add wave -position end sim:/data_memory_tb/readwrite_flag
    add wave -position end sim:/data_memory_tb/mem_flag
}

vlib work

;# Compile components if any
vcom data_memory.vhd
vcom data_memory_tb.vhd


;# Start simulation
vsim data_memory_tb

;# Generate a clock with 1ns period
force -deposit clock 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 15ns
run 5ns