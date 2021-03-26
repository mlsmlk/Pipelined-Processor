proc AddWaves {} {
	;#Add waves we're interested in to the Wave window
    add wave -position end sim:/Test_Programs/write_back_tb/clk
    add wave -position end sim:/Test_Programs/write_back_tb/mem_flag
    add wave -position end sim:/Test_Programs/write_back_tb/write_data
}

vlib work

;# Compile components if any
vcom src/write_back.vhd
vcom Test_Programs/write_back_tb.vhd

;# Start simulation
vsim Test_Programs/write_back_tb

;# Generate a clock with 1ns period
force -deposit clk 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 50 ns
run 50ns