# Group 18's ECSE 425 Pipelined Processor Project
Welcome to our pipelined processor project!

## How to run a program
1. Use the Assembler provided by the instructor to generate a program file with machine level instructions.
2. Place the program file into the `src` directory of our project.
3. **Ensure the name of the program file is `program.txt`.**
4. In ModelSim, `cd` into the `src` directory and run the `Pipelined_Processor_tb.tcl` file.
5. The program should run for 10000 clock cycles, after which two files will be generated in the `src` directory:
   1. `memory.txt`: contains the contents of the memory
   2. `registers.txt`: contains the contents of the registers
