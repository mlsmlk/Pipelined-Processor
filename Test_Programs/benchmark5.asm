# Program for sw after branch
            addi    $1, $0, 4
            addi    $2, $1, 4
            bne     $1, $2, end
            sw      $1, 8($2)
end:        j       end