proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/data_memory_tb/clk
    add wave -position end sim:/data_memory_tb/alu_in
    add wave -position end sim:/data_memory_tb/mem_in
    add wave -position end sim:/data_memory_tb/mem_res
    add wave -position end sim:/data_memory_tb/alu_res
    add wave -position end sim:/data_memory_tb/readwrite_flag
    add wave -position end sim:/data_memory_tb/mem_flag
    add wave -position end sim:/data_memory_tb/m_readdata
    add wave -position end sim:/data_memory_tb/m_writedata
    add wave -position end sim:/data_memory_tb/m_waitrequest
    add wave -position end sim:/data_memory_tb/m_read
    add wave -position end sim:/data_memory_tb/m_write
    add wave -position end sim:/data_memory_tb/mem_busy
}

vlib work

;# Compile components if any
vcom data_memory.vhd
vcom data_memory_tb.vhd
vcom memory.vhd
vcom memory_tb.vhd

;# Start simulation
vsim data_memory_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 250 ns
run 350ns