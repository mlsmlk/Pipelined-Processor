library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity decode is
    port(
        --- INPUTS ---
        -- Clock --
        clock : in std_logic;

        -- Flag for writing the register file to a text file
        write_reg_file : in std_logic;

        -- From the Fetch stage --
        -- The instruction to be parsed
        f_instruction : in std_logic_vector(31 downto 0);
        -- Reset flag
        f_reset : in std_logic;
        -- PC + 4
        f_pcplus4 : in std_logic_vector(31 downto 0);

        -- From the Writeback stage --
        -- Data to be written back to a register
        w_regdata : in std_logic_vector(31 downto 0);

        --- OUTPUTS ---
        -- To the Fetch stage --
        -- Signals if the pipeline should be stalled
        f_stall : out std_logic;

        -- To the Execute stage --
        -- Instruction type
        -- "00" = R-type || "01" = I-type || "10" == J-type
        e_insttype : out std_logic_vector(1 downto 0);
        -- opcode for I-type and J-type, or funct for R-type
        e_opcode : out std_logic_vector(5 downto 0);
        -- Data 1
        e_readdata1 : out std_logic_vector(31 downto 0);
        -- Data 2
        e_readdata2 : out std_logic_vector(31 downto 0);
        -- Extended immediate value
        e_imm : out std_logic_vector(31 downto 0);
        -- Signal to Execute to use the forwarded value from Execute
        e_forward_ex : out std_logic;
        -- Indicate which operand the forwarded value from Execute maps to
        -- "10" = readdata1 || "01" = readdata2 || "11" = both
        e_forwardop_ex : out std_logic_vector(1 downto 0);
        -- Signal to Execute to use the forwarded value from Memory
        e_forward_mem : out std_logic;
        -- Indicate which operand the forwarded value from Memory maps to
        -- "10" = readdata1 || "01" = readdata2 || "11" = both
        e_forwardop_mem : out std_logic_vector(1 downto 0);
        -- Signal to Execute whether to use memory value or previous ALU value
        -- '0' = ALU value || '1' = memory value
        e_forwardport_mem : out std_logic
    );
end decode;

architecture arch of decode is
    ----- CONSTANTS -----
    constant NUM_REGISTERS : natural := 32;
    constant LR_IDX : natural := 31; -- Link register index

    ----- OPCODES -----
    --- R-type
    constant ADD : std_logic_vector(5 downto 0) := "100000";
    constant SUB : std_logic_vector(5 downto 0) := "100010";
    constant MULT : std_logic_vector(5 downto 0) := "011000";
    constant DIV : std_logic_vector(5 downto 0) := "011010";
    constant SLT : std_logic_vector(5 downto 0) := "101010";
    constant L_AND : std_logic_vector(5 downto 0) := "100100";
    constant L_OR : std_logic_vector(5 downto 0) := "100101";
    constant L_NOR : std_logic_vector(5 downto 0) := "100111";
    constant L_XOR : std_logic_vector(5 downto 0) := "100110";
    constant MFHI : std_logic_vector(5 downto 0) := "010000";
    constant MFLO : std_logic_vector(5 downto 0) := "010010";
    constant S_SLL : std_logic_vector(5 downto 0) := "000000";
    constant S_SRL : std_logic_vector(5 downto 0) := "000010";
    constant S_SRA : std_logic_vector(5 downto 0) := "000011";
    constant JR : std_logic_vector(5 downto 0) := "001000";
    
    --- I-type
    -- Arithmetic
    constant ADDI : std_logic_vector(5 downto 0) := "001000";
    constant SLTI : std_logic_vector(5 downto 0) := "001010";
    -- Logical
    constant ANDI : std_logic_vector(5 downto 0) := "001100";
    constant ORI : std_logic_vector(5 downto 0) := "001101";
    constant XORI : std_logic_vector(5 downto 0) := "001110";
    -- Transfer
    constant LUI : std_logic_vector(5 downto 0) := "001111";
    -- Memory
    constant LW : std_logic_vector(5 downto 0) := "100011";			
    constant SW : std_logic_vector(5 downto 0) := "101011";					
    -- Control-flow
    constant BEQ : std_logic_vector(5 downto 0) := "000100";
    constant BNE : std_logic_vector(5 downto 0) := "000101";
    
    --- J-type
    constant J : std_logic_vector(5 downto 0) := "000010";
    constant JAL : std_logic_vector(5 downto 0) := "000011";

    ----- TYPE DEFINITIONS -----
    type writeback_queue is array(0 to 2) of natural range 0 to NUM_REGISTERS - 1;
    type instruction_is_load_queue is array(0 to 2) of std_logic;
    type register_file is array(0 to NUM_REGISTERS - 1) of std_logic_vector(31 downto 0);

    ----- SIGNALS -----
    -- Register file
    signal registers : register_file;
    -- For writing back
    signal wb_queue : writeback_queue; -- Stores which register will be written back to next
    signal is_load_queue : instruction_is_load_queue; -- Stores the associated instruction with each register
    signal wb_queue_idx : natural range 0 to 2 := 0;
    -- For stalls
    signal stalled_inst : std_logic_vector(31 downto 0); -- Store the stalled instruction
    -- Output registers
    signal sig_stall : std_logic;
    signal sig_insttype : std_logic_vector(1 downto 0);
    signal sig_opcode : std_logic_vector(5 downto 0);
    signal sig_readdata1 : std_logic_vector(31 downto 0);
    signal sig_readdata2 : std_logic_vector(31 downto 0);
    signal sig_imm : std_logic_vector(31 downto 0);
    signal sig_forward_ex : std_logic;
    signal sig_forwardop_ex : std_logic_vector(1 downto 0);
    signal sig_forward_mem : std_logic;
    signal sig_forwardop_mem : std_logic_vector(1 downto 0);
    signal sig_forwardport_mem : std_logic;
    -- FUNCTIONS --
    impure function IS_HAZARD (reg : integer; writebackq : writeback_queue)
            return boolean is
    begin
        -- A register-related hazard only occurs if
        -- (1) The target register is not $0 (nothing is ever written to it)
        -- AND
        -- (2) The target register is not being written back to in this clock cycle
        -- AND
        -- (3) The target register is present in one of the other positions in the writeback queue
        if (wb_queue_idx = 0) then
            return (reg /= 0) and (reg /= writebackq(0)) and (reg = writebackq(1) or reg = writebackq(2));
        elsif (wb_queue_idx = 1) then
            return (reg /= 0) and (reg /= writebackq(1)) and (reg = writebackq(0) or reg = writebackq(2));
        else
            return (reg /= 0) and (reg /= writebackq(2)) and (reg = writebackq(0) or reg = writebackq(1));
        end if;
    end function;

    impure function CAN_FORWARD_EX(reg : integer; writebackq : writeback_queue)
                return boolean is
        variable prev_wb_idx : natural range 0 to 2 := 0;
    begin
        -- Get the writeback index for the instruction in Execute
        if (wb_queue_idx = 0) then
            prev_wb_idx := 2;
        else
            prev_wb_idx := wb_queue_idx - 1;
        end if;
        -- If the instruction in Execute is going to write back to the target register, we can
        -- forward the value instead. The instruction cannot be a load instruction
        return (writebackq(prev_wb_idx) = reg) and (is_load_queue(prev_wb_idx) = '0');
    end function;

    impure function CAN_FORWARD_MEM(reg : integer; writebackq : writeback_queue)
                return boolean is
        variable next_wb_idx : natural range 0 to 2 := 0;
    begin
        -- Get the writeback index for the instruction in Memory
        if (wb_queue_idx = 2) then
            next_wb_idx := 0;
        else
            next_wb_idx := wb_queue_idx + 1;
        end if;
        -- If the instruction in Memory is going to write back to the target register, we can
        -- forward the value instead
        return writebackq(next_wb_idx) = reg;
    end function;

begin
    -- Prints out the register file when the flag is raised
    print_reg_file: process (write_reg_file)
        file register_file : text open write_mode is "registers.txt";
        variable line_out : line;
    begin
        if (rising_edge(write_reg_file)) then
            for i in 0 to NUM_REGISTERS - 1 loop
                write(line_out, registers(i));
                writeline(register_file, line_out);
            end loop;
        end if;
    end process;

    decode_proc: process (clock, f_reset)
        ----- VARIABLES -----
        -- Replica of the register file to help simplify the write back process
        variable registers_var : register_file;
		-- Replica of writeback queue
		variable var_wb_queue : writeback_queue;
        -- General instruction components
        variable instruction : std_logic_vector(31 downto 0);
        variable opcode : std_logic_vector(5 downto 0);
        variable reg_s_idx : natural range 0 to NUM_REGISTERS - 1; -- First operand register index
        variable reg_s_data : std_logic_vector(31 downto 0); -- First operand register data
        variable reg_t_idx : natural range 0 to NUM_REGISTERS - 1; -- Second operand register index
        variable reg_t_data : std_logic_vector(31 downto 0); -- Second operand register data
        -- R-type instruction components
        variable reg_d_idx : natural range 0 to NUM_REGISTERS - 1; -- Destination register index
        variable shamt : std_logic_vector(4 downto 0); -- Used for shift operations
        variable funct : std_logic_vector(5 downto 0); -- Specifies the operation to perform
        -- I-type instruction components
        variable imm : std_logic_vector(15 downto 0); -- Immediate value
        -- J-type instruction components
        variable address : std_logic_vector(25 downto 0); -- Address for jump instruction
        -- Variables used in hazard detection
        variable hazard_exists : std_logic := '0';
        -- Variable used in forwarding
        variable forward_ex : std_logic;
        variable op_ex : std_logic_vector(1 downto 0); -- Temporary variable for the execute operator
        variable forward_mem : std_logic;
        variable op_mem : std_logic_vector(1 downto 0); -- Temporary variable for the memory operator
        variable next_wb_idx : natural range 0 to 2;
    begin
        -- Create an alias of the register file to allow the register file to be changed within CC
        registers_var := registers;
		-- Similarly for the writeback queue
		var_wb_queue := wb_queue;

        -- If just starting, set all registers to 0
        if (now < 1 ps) then
            -- Set register 0 to have a value of 0
            for i in 0 to NUM_REGISTERS - 1 loop
                registers_var(i) := (others => '0');
            end loop;
            -- Clear the queue
            for i in 0 to 2 loop
                var_wb_queue(i) := 0;
                is_load_queue(i) <= '0';
            end loop;
            wb_queue_idx <= 0;
            -- Clear forwarding signals
            sig_forward_ex <= '0';
            sig_forward_mem <= '0';

        -- Process incoming instruction
        elsif (rising_edge(clock)) then
            -- If a branch was taken, the pipeline must be flushed
            if (f_reset = '1') then
                -- Set register 0 to have a value of 0
                registers_var(0) := (others => '0');
                -- Clear the queue
                for i in 0 to 2 loop
                    var_wb_queue(i) := 0;
                    is_load_queue(i) <= '0';
                end loop;
                -- Clear forwarding signals
                sig_forward_ex <= '0';
                sig_forward_mem <= '0';
            -- Perform a writeback operation if necessary
            elsif (var_wb_queue(wb_queue_idx) /= 0) then
                registers_var(var_wb_queue(wb_queue_idx)) := w_regdata;
            end if;

            -- If a stall is happening, use the stalled instruction, not the one shown by Fetch
            if (sig_stall = '1') then
                instruction := stalled_inst;
            else
                instruction := f_instruction;
            end if;

            -- Assume no hazard exists until one is detected
            hazard_exists := '0';

            -- Choose the memory forwarded port based on whether or not the instruction is a load
            if (wb_queue_idx = 2) then
                next_wb_idx := 0;
            else
                next_wb_idx := wb_queue_idx + 1;
            end if;
            sig_forwardport_mem <= is_load_queue(next_wb_idx);

            -- Identify the type of the instruction
            opcode := instruction(31 downto 26);
            if (opcode = "000000") then
                -- R-type instruction
                sig_insttype <= "00";
                reg_s_idx := to_integer(unsigned(instruction(25 downto 21)));
                reg_t_idx := to_integer(unsigned(instruction(20 downto 16)));
                reg_d_idx := to_integer(unsigned(instruction(15 downto 11)));
                shamt := instruction(10 downto 6);
                funct := instruction(5 downto 0);
                
                -- Use funct as the opcode
                sig_opcode <= funct;

                -- Check for any hazards
                forward_ex := '0';
                op_ex := "00";
                forward_mem := '0';
                op_mem := "00";

                if (IS_HAZARD(reg_s_idx, var_wb_queue)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_s_idx, var_wb_queue)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := "10";
                    elsif (CAN_FORWARD_MEM(reg_s_idx, var_wb_queue)) then
                        -- Forward the memory output to the execute input
                        forward_mem := '1';
                        op_mem := "10";
                    else
                        -- Must stall
                        forward_ex := '0';
                        forward_mem := '0';
                        hazard_exists := '1';
                    end if;
                end if;
                if (IS_HAZARD(reg_t_idx, var_wb_queue)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_t_idx, var_wb_queue)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := op_ex or "01";
                    elsif (CAN_FORWARD_MEM(reg_t_idx, var_wb_queue)) then
                        -- Forward the memory output to the execute input
                        forward_mem := '1';
                        op_mem := op_mem or "01";
                    else
                        -- Must stall
                        forward_ex := '0';
                        forward_mem := '0';
                        hazard_exists := '1';
                    end if;
                end if;

                sig_forward_ex <= forward_ex;
                sig_forwardop_ex <= op_ex;
                sig_forward_mem <= forward_mem;
                sig_forwardop_mem <= op_mem;

                -- If no hazards present, prepare the next instruction, even if one or both of
                -- the values is going to be forwarded
                if (hazard_exists = '0') then
                    -- Don't need to worry about forwarding here because the forwarding flag will
                    -- force Execute to ignore any value coming out of readdata
                    
                    -- If the instruction is a shift, use shamt instead of Rs for readdata1
                    if (funct = S_SLL or funct = S_SRL or funct = S_SRA) then
                        sig_readdata1 <= std_logic_vector(resize(unsigned(shamt), 32));
                    else
                        sig_readdata1 <= registers_var(reg_s_idx);
                    end if;

                    -- Set Rt to be the other output
                    sig_readdata2 <= registers_var(reg_t_idx);

                    -- For all instructions other than jump register, set Rd as writeback
                    if (funct /= JR and funct /= MULT and funct /= DIV) then
                        var_wb_queue(wb_queue_idx) := reg_d_idx;
                    else
                        var_wb_queue(wb_queue_idx) := 0;
                    end if;

                    -- Store the funct for forwarding purposes
                    is_load_queue(wb_queue_idx) <= '0';
                end if;
            elsif (opcode = J or opcode = JAL) then
                -- J-type instruction
                sig_insttype <= "10";
                sig_opcode <= opcode;
                address := instruction(25 downto 0);
                
                -- No forwarding with J-type instructions
                sig_forward_ex <= '0';
                sig_forward_mem <= '0';

                -- If jump and link, update the link register with PC + 8
                if (opcode = JAL) then
                    registers_var(LR_IDX) := std_logic_vector(unsigned(f_pcplus4) + 4);
                end if;
                
                -- Format the output address according to the specification
                sig_readdata1 <= f_pcplus4(31 downto 28) & address & "00";
                
                -- No write back for J-type instructions
                var_wb_queue(wb_queue_idx) := 0;

                -- Store the opcode for forwarding purposes
                is_load_queue(wb_queue_idx) <= '0';
            else
                -- I-type instruction
                sig_insttype <= "01";
                sig_opcode <= opcode;
                reg_s_idx := to_integer(unsigned(instruction(25 downto 21)));
                reg_t_idx := to_integer(unsigned(instruction(20 downto 16)));
                imm := instruction(15 downto 0);

                -- Check for any hazards
                forward_ex := '0';
                op_ex := "00";
                forward_mem := '0';
                op_mem := "00";

                if (IS_HAZARD(reg_s_idx, var_wb_queue)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_s_idx, var_wb_queue)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := "10";
                    elsif (CAN_FORWARD_MEM(reg_s_idx, var_wb_queue)) then
                        -- Forward the memory output to the execute input
                        forward_mem := '1';
                        op_mem := "10";
                    else
                        -- Must stall
                        forward_ex := '0';
                        forward_mem := '0';
                        hazard_exists := '1';
                    end if;
                end if;
                if ((opcode = BEQ or opcode = BNE or opcode = SW) and IS_HAZARD(reg_t_idx, var_wb_queue)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_t_idx, var_wb_queue)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := op_ex or "01";
                    elsif (CAN_FORWARD_MEM(reg_t_idx, var_wb_queue)) then
                        -- Forward the memory output to the execute input
                        forward_mem := '1';
                        op_mem := op_mem or "01";
                    else
                        -- Must stall
                        forward_ex := '0';
                        forward_mem := '0';
                        hazard_exists := '1';
                    end if;
                end if;

                sig_forward_ex <= forward_ex;
                sig_forwardop_ex <= op_ex;
                sig_forward_mem <= forward_mem;
                sig_forwardop_mem <= op_mem;

                if (hazard_exists = '0') then
                    -- Don't need to worry about forwarding here because the forwarding flag will
                    -- force Execute to ignore any value coming out of readdata

                    -- Output the Rs value
                    sig_readdata1 <= registers_var(reg_s_idx);

                    -- Extend the immediate value
                    case (opcode) is
                        when BEQ | BNE =>
                            -- Address extend
                            sig_imm <= std_logic_vector(shift_left(resize(signed(imm), 32), 2));
                        when LUI | ANDI | ORI | XORI =>
                            -- Zero extend
                            sig_imm <= std_logic_vector(resize(unsigned(imm), 32));
                        when others =>
                            -- Sign extend
                            sig_imm <= std_logic_vector(resize(signed(imm), 32));
                    end case;                    

                    -- Add writeback register to queue, if there is one
                    if (opcode /= BEQ and opcode /= BNE and opcode /= SW) then
                        var_wb_queue(wb_queue_idx) := reg_t_idx;
                    else
                        var_wb_queue(wb_queue_idx) := 0;
						sig_readdata2 <= registers_var(reg_t_idx);
                    end if;

                    -- If instruction is a load, take note for forwarding purposes
                    if (opcode = LW) then
                        is_load_queue(wb_queue_idx) <= '1';
                    else
                        is_load_queue(wb_queue_idx) <= '0';
                    end if;
                end if;
            end if;

            -- Deal with a hazard by stalling the pipeline
            if (hazard_exists = '1') then
                -- Stall pipeline with 'addi $0 $0 0' instruction
                sig_insttype <= "01";
                sig_opcode <= ADDI;
                sig_readdata1 <= (others => '0');
                sig_imm <= (others => '0');
                var_wb_queue(wb_queue_idx) := 0;
                is_load_queue(wb_queue_idx) <= '0';

                -- Signal to the instruction fetch stage to stop processing instructions
                sig_stall <= '1';

                -- Save the stalled instruction
                stalled_inst <= instruction;
            else
                -- Safe to continue processing instructions
                sig_stall <= '0';
            end if;

            -- Increment the write back index
            if (wb_queue_idx = 2) then
                wb_queue_idx <= 0;
            else
                wb_queue_idx <= wb_queue_idx + 1;
            end if;
        end if;

        -- Update the true register file with the temporary register file
        registers <= registers_var;
		-- Similarly for the writeback queue
		wb_queue <= var_wb_queue;
    end process;

    -- Assign registers to outputs
    f_stall	<= sig_stall;
    e_insttype      <= sig_insttype;
    e_opcode        <= sig_opcode;
    e_readdata1     <= sig_readdata1;
    e_readdata2     <= sig_readdata2;
    e_imm           <= sig_imm;
    e_forward_ex    <= sig_forward_ex;
    e_forwardop_ex  <= sig_forwardop_ex;
    e_forward_mem   <= sig_forward_mem;
    e_forwardop_mem <= sig_forwardop_mem;
	e_forwardport_mem <= sig_forwardport_mem;
end arch;
