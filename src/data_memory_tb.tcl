proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/data_memory/clk
    add wave -position end sim:/data_memory/alu_in
    add wave -position end sim:/data_memory/mem_in
    add wave -position end sim:/data_memory/mem_res
    add wave -position end sim:/data_memory/alu_res
    add wave -position end sim:/data_memory/readwrite_flag
    add wave -position end sim:/data_memory/mem_flag
    add wave -position end sim:/data_memory/writedata
    add wave -position end sim:/data_memory/address
    add wave -position end sim:/data_memory/memwrite
    add wave -position end sim:/data_memory/memread
    add wave -position end sim:/data_memory/readdata

}

vlib work

;# Compile components if any
vcom data_memory.vhd
vcom data_memory_tb.vhd
vcom memory.vhd
vcom memory_tb.vhd

;# Start simulation
vsim data_memory

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 250 ns
run 250ns