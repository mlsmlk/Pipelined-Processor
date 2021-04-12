proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
	add wave -position end  sim:/instruction_memory_tb/dut/clock
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