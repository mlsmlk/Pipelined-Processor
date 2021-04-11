proc AddWaves {} {
    ;# Add important waves to the Wave window
    add wave -position end  sim:/decode_tb/dec/clock
    add wave -position end  sim:/decode_tb/dec/f_instruction
    add wave -position end  sim:/decode_tb/dec/f_reset
    add wave -position end  sim:/decode_tb/dec/f_pcplus4
    add wave -position end  sim:/decode_tb/dec/w_regdata
    add wave -position end  sim:/decode_tb/dec/registers
    add wave -position end  sim:/decode_tb/dec/wb_queue
    add wave -position end  sim:/decode_tb/dec/is_load_queue
    add wave -position end  sim:/decode_tb/dec/wb_queue_idx
    add wave -position end  sim:/decode_tb/dec/sig_stall
    add wave -position end  sim:/decode_tb/dec/sig_insttype
    add wave -position end  sim:/decode_tb/dec/sig_opcode
    add wave -position end  sim:/decode_tb/dec/sig_readdata1
    add wave -position end  sim:/decode_tb/dec/sig_readdata2
    add wave -position end  sim:/decode_tb/dec/sig_imm
    add wave -position end  sim:/decode_tb/dec/sig_forward_ex
    add wave -position end  sim:/decode_tb/dec/sig_forwardop_ex
    add wave -position end  sim:/decode_tb/dec/sig_forward_mem
    add wave -position end  sim:/decode_tb/dec/sig_forwardop_mem
}

vlib work

;# Compile components
vcom Decode.vhd
vcom Decode_tb.vhd

;# Start simulation
vsim Decode_tb

;# Generate a 1 ns period clock
force -deposit clock 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 50 ns
run 50ns