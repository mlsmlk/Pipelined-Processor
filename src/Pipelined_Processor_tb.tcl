proc AddWaves {} {
    ;# Add important waves to the Wave window
    add wave -position end  sim:/pipelined_processor_tb/proc/clock
    add wave -position end  sim:/pipelined_processor_tb/proc/reset
    add wave -position end  sim:/pipelined_processor_tb/proc/write_to_file
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
