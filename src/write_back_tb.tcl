proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/wb_tb/mem_flag
    add wave -position end sim:/wb_tb/write_data
}


;# Compile components if any
vcom write_back.vhd
vcom write_back_tb.vhd

;# Start simulation
vsim wb_tb 

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 5 ns
run 5 ns