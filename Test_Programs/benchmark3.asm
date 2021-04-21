###############################################
# $1: input n
# $2: output n!

	addi  $1, $0, 2         # input 2
        addi  $2, $0, 1         # output
loop:   slti  $3, $1, 2         # n<2?
        bne   $3, $0, end       # return 1
        mult  $1, $2            # n * n
        mflo  $2                
        addi  $1, $1, -1        # n--
        j     loop              # loop
end:	jr    $31               # return
###############################################
