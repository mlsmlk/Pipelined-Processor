proc AddWaves {} {
    ;# Add important waves to the Wave window
    add wave -position end  sim:/execute_tb/exec/clock
    add wave -position end  sim:/execute_tb/exec/f_reset
    add wave -position end  sim:/execute_tb/exec/f_nextPC
    add wave -position end  sim:/execute_tb/exec/e_insttype
    add wave -position end  sim:/execute_tb/exec/e_opcode
    add wave -position end  sim:/execute_tb/exec/e_readdata1
    add wave -position end  sim:/execute_tb/exec/e_readdata2
    add wave -position end  sim:/execute_tb/exec/e_imm
    add wave -position end  sim:/execute_tb/exec/e_forward_ex
    add wave -position end  sim:/execute_tb/exec/e_forwardop_ex
    add wave -position end  sim:/execute_tb/exec/e_forward_mem
    add wave -position end  sim:/execute_tb/exec/e_forwardop_mem
    add wave -position end  sim:/execute_tb/exec/m_forward_data

    add wave -position end  sim:/execute_tb/exec/alu_result
    add wave -position end  sim:/execute_tb/exec/writedata
    add wave -position end  sim:/execute_tb/exec/readwrite_flag
    add wave -position end  sim:/execute_tb/exec/branch_taken
    add wave -position end  sim:/execute_tb/exec/branch_target_addr

    add wave -position end  sim:/execute_tb/exec/HI
    add wave -position end  sim:/execute_tb/exec/LO
}

vlib work

;# Compile components
vcom Execute.vhd -2008
vcom Execute_tb.vhd -2008

;# Start simulation
vsim Execute_tb

;# Generate a 1 ns period clock
force -deposit clock 0 0 ns, 1 0.5 ns -repeat 1 ns

;# Add the waves
AddWaves

;# Run for 25 ns
run 50ns