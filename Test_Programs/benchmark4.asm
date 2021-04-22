# Program for testing subroutines and loads
            addi    $1, $0, 4
            addi    $2, $1, 4
            sw      $1, 8($2)
            jal     routine
            lw      $3, 8($2)
end:        j       end

routine:    addi    $4, $1, -1
            mult    $4, $1
            mflo    $5
            jr      $31         # Jump back to link register

