library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decode is
    port(
        --- INPUTS ---
        -- Clock --
        clock : in std_logic;

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
        e_forwardop_mem : out std_logic_vector(1 downto 0)
    );
end decode;

architecture arch of decode is
    ----- CONSTANTS -----
    constant NUM_REGISTERS : natural := 32;
    constant LR_IDX : natural := 31; -- Link register index

    ----- OPCODES -----
	--- R-type
	constant ADD : opcode := "100000";
	constant SUB : opcode := "100010";
	constant MULT : opcode := "011000";
	constant DIV : opcode := "011010";
	constant SLT : opcode := "101010";
	constant L_AND : opcode := "100100";
	constant L_OR : opcode := "100101";
	constant L_NOR : opcode := "100111";
	constant L_XOR : opcode := "100110";
	constant MFHI : opcode := "010000";
	constant MFLO : opcode := "010010";
	constant S_SLL : opcode := "000000";
	constant S_SRL : opcode := "000010";
	constant S_SRA : opcode := "000011";
	constant JR : opcode := "001000";
	
	--- I-type
	-- Arithmetic
	constant ADDI : opcode := "001000";
	constant SLTI : opcode := "001010";
	-- Logical
	constant ANDI : opcode := "001100";
	constant ORI : opcode := "001101";
	constant XORI : opcode := "001110";
	-- Transfer
	constant LUI : opcode := "001111";
	-- Memory
	constant LW : opcode := "100011";			
	constant SW : opcode := "101011";					
	-- Control-flow
	constant BEQ : opcode := "000100";
	constant BNE : opcode := "000101";
	
	--- J-type
	constant J : opcode := "000010";
	constant JAL : opcode := "000011";

    ----- TYPE DEFINITIONS -----
    type writeback_queue is array(0 to 2) of natural range 0 to NUM_REGISTERS - 1;
    type instruction_is_load_queue is array(0 to 2) of std_logic;
    type register_file is array(0 to NUM_REGISTERS - 1) of std_logic_vector(31 downto 0);

    ----- SIGNALS -----
    -- Register file
    signal registers: register_file;
    -- For writing back
    signal wb_queue: writeback_queue; -- Stores which register will be written back to next
    signal is_load_queue: instruction_is_load_queue; -- Stores the associated instruction with each register
    signal wb_queue_idx : natural range 0 to 2 := 0;
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
    -- FUNCTIONS --
    impure function IS_HAZARD (reg : integer)
            return boolean is
    begin
        -- A register-related hazard only occurs if
        -- (1) The target register is not $0 (nothing is ever written to it)
        -- AND
        -- (2) The target register is not being written back to in this clock cycle
        -- AND
        -- (3) The target register is present in one of the other positions in the writeback queue
        if (wb_queue_idx = 0) then
            return (reg /= 0) and (reg /= wb_queue(0)) and (reg = wb_queue(1) or reg = wb_queue(2));
        elsif (wb_queue_idx = 1) then
            return (reg /= 0) and (reg /= wb_queue(1)) and (reg = wb_queue(0) or reg = wb_queue(2));
        else
            return (reg /= 0) and (reg /= wb_queue(2)) and (reg = wb_queue(0) or reg = wb_queue(1));
        end if;
    end function;

    impure function CAN_FORWARD_EX(reg : integer)
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
        return (wb_queue(prev_wb_idx) = reg) and (is_load_queue(prev_wb_idx) = '0');
    end function;

    impure function CAN_FORWARD_MEM(reg : integer)
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
        return wb_queue(next_wb_idx) = reg;
    end function;

begin
    decode_proc: process (clock, f_reset)
        ----- VARIABLES -----
        -- Replica of the register file to help simplify the write back process
        variable registers_var : register_file;
        -- General instruction components
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
    begin
        -- Create an alias of the register file to allow the register file to be changed within CC
        registers_var := registers;

        -- Either starting up or a branch was taken, so the pipeline must be flushed
        if (f_reset = '1') or (now < 1 ps) then
            -- Set register 0 to have a value of 0
            registers_var(0) := (others => '0');
            -- Clear the queue
            for i in 0 to 2 loop
				wb_queue(i) <= 0;
                is_load_queue(i) <= '0';
			end loop;
            wb_queue_idx <= 0;
            -- Clear forwarding signals
            sig_forward_ex <= '0';
            sig_forward_mem <= '0';

        -- Process incoming instruction
        elsif (rising_edge(clock)) then
            -- Perform a writeback operation if necessary
            if (wb_queue(wb_queue_idx) /= 0) then
                registers_var(wb_queue(wb_queue_idx)) := w_regdata;
            end if;

            -- Identify the type of the instruction
            opcode := f_instruction(31 downto 26);
            if (opcode = "000000") then
                -- R-type instruction
                sig_insttype <= "00";
                reg_s_idx := to_integer(unsigned(f_instruction(25 downto 21)));
                reg_t_idx := to_integer(unsigned(f_instruction(20 downto 16)));
                reg_d_idx := to_integer(unsigned(f_instruction(15 downto 11)));
                shamt := f_instruction(10 downto 6);
                funct := f_instruction(5 downto 0);
                
                -- Use funct as the opcode
                sig_opcode <= funct;

                -- Check for any hazards
                hazard_exists := '0';
                forward_ex := '0';
                op_ex := "00";
                forward_mem := '0';
                op_mem := "00";

                if (IS_HAZARD(reg_s_idx)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_s_idx)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := "10";
                    elsif (CAN_FORWARD_MEM(reg_s_idx)) then
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
                if (IS_HAZARD(reg_t_idx)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_t_idx)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := op_ex or "01";
                    elsif (CAN_FORWARD_MEM(reg_t_idx)) then
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
                        wb_queue(wb_queue_idx) <= reg_d_idx;
                    else
                        wb_queue(wb_queue_idx) <= 0;
                    end if;

                    -- Store the funct for forwarding purposes
                    is_load_queue(wb_queue_idx) <= '0';
                end if;
            elsif (opcode = J or opcode = JAL) then
                -- J-type instruction
                sig_insttype <= "10";
                sig_opcode <= opcode;
                address := f_instruction(25 downto 0);
                
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
                wb_queue(wb_queue_idx) <= 0;

                -- Store the opcode for forwarding purposes
                is_load_queue(wb_queue_idx) <= '0';
            else
                -- I-type instruction
                sig_insttype <= "01";
                sig_opcode <= opcode;
                reg_s_idx := to_integer(unsigned(f_instruction(25 downto 21)));
                reg_t_idx := to_integer(unsigned(f_instruction(20 downto 16)));
                imm := f_instruction(15 downto 0);

                -- Check for any hazards
                hazard_exists := '0';
                forward_ex := '0';
                op_ex := "00";
                forward_mem := '0';
                op_mem := "00";

                if (IS_HAZARD(reg_s_idx)) then
                    -- Check to see if we can forward the value instead of stalling
                    if (CAN_FORWARD_EX(reg_s_idx)) then
                        -- Forward the execute output to the execute input
                        forward_ex := '1';
                        op_ex := "10";
                    elsif (CAN_FORWARD_MEM(reg_s_idx)) then
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
                        wb_queue(wb_queue_idx) <= reg_t_idx;
                    else
                        wb_queue(wb_queue_idx) <= 0;
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
                wb_queue(wb_queue_idx) <= 0;
                is_load_queue(wb_queue_idx) <= '0';

                -- Signal to the instruction fetch stage to stop processing instructions
                sig_stall <= '1';
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
end arch;
