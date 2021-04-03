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
        -- Signal to execute or memory stage to forward a value
        e_forward : out std_logic
    );
end decode;

architecture arch of decode is
    ----- CONSTANTS -----
    constant NUM_REGISTERS : natural := 32;
    constant LR_IDX : natural := 31; -- Link register index

    ----- TYPE DEFINITIONS -----
    type writeback_queue is array(0 to 2) of natural range 0 to NUM_REGISTERS - 1;
    type register_file is array(0 to NUM_REGISTERS - 1) of std_logic_vector(31 downto 0);

    ----- SIGNALS -----
    -- Register file
    signal registers: register_file;
    -- For writing back
    signal wb_queue: writeback_queue; -- Stores which register will be written back to next
    signal wb_queue_idx : natural range 0 to 2 := 0;
    -- Output registers
    signal sig_stall : std_logic;
    signal sig_insttype : std_logic_vector(1 downto 0);
    signal sig_opcode : std_logic_vector(5 downto 0);
    signal sig_readdata1 : std_logic_vector(31 downto 0);
    signal sig_readdata2 : std_logic_vector(31 downto 0);
    signal sig_imm : std_logic_vector(31 downto 0);

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
			end loop;
            wb_queue_idx <= 0;

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
                if (IS_HAZARD(reg_s_idx) or IS_HAZARD(reg_t_idx)) then
                    hazard_exists := '1';
                else
                    hazard_exists := '0';

                    -- If the instruction is a shift, use shamt instead of Rs for readdata1
                    if (funct = "000000" or funct = "000010" or funct = "000011") then
                        sig_readdata1 <= std_logic_vector(resize(unsigned(shamt), 32));
                    else
                        sig_readdata1 <= registers_var(reg_s_idx);
                    end if;

                    -- Set Rt to be the other output
                    sig_readdata2 <= registers_var(reg_t_idx);

                    -- For all instructions other than jump register, set Rd as writeback
                    if (funct /= "001000") then
                        wb_queue(wb_queue_idx) <= reg_d_idx;
                    else
                        wb_queue(wb_queue_idx) <= 0;
                    end if;
                end if;
            elsif (opcode = "000011" or opcode = "000010") then
                -- J-type instruction
                sig_insttype <= "10";
                sig_opcode <= opcode;
                address := f_instruction(25 downto 0);
                
                -- If jump and link, update the link register with PC + 8
                if (opcode = "000011") then
                    registers_var(LR_IDX) := std_logic_vector(unsigned(f_pcplus4) + 4);
                end if;
                
                -- Format the output address according to the specification
                sig_readdata1 <= f_pcplus4(31 downto 28) & address & "00";
                
                -- No write back for J-type instructions
                wb_queue(wb_queue_idx) <= 0;
            else
                -- I-type instruction
                sig_insttype <= "01";
                sig_opcode <= opcode;
                reg_s_idx := to_integer(unsigned(f_instruction(25 downto 21)));
                reg_t_idx := to_integer(unsigned(f_instruction(20 downto 16)));
                imm := f_instruction(15 downto 0);

                -- Check for any hazards
                if (IS_HAZARD(reg_s_idx)) then
                    hazard_exists := '1';
                else
                    hazard_exists := '0';

                    -- Output the Rs value
                    sig_readdata1 <= registers_var(reg_s_idx);

                    -- Extend the immediate value
                    case (opcode) is
                        when "001111" =>
                            -- Upper immediate shift
                            sig_imm <= std_logic_vector(shift_left(resize(unsigned(imm), 32), 16));
                        when "000100" | "000101" =>
                            -- Address extend
                            sig_imm <= std_logic_vector(shift_left(resize(signed(imm), 32), 2));
                        when "001100" | "001101" | "001110" =>
                            -- Zero extend
                            sig_imm <= std_logic_vector(resize(unsigned(imm), 32));
                        when others =>
                            -- Sign extend
                            sig_imm <= std_logic_vector(resize(signed(imm), 32));
                    end case;                    

                    -- Add writeback register to queue, if there is one
                    if (opcode /= "000100" and opcode /= "000101" and opcode /= "101011") then
                        wb_queue(wb_queue_idx) <= reg_t_idx;
                    else
                        wb_queue(wb_queue_idx) <= 0;
                    end if;
                end if;
            end if;

            -- Deal with a hazard by stalling the pipeline
            if (hazard_exists = '1') then
                -- Stall pipeline with 'addi $0 $0 0' instruction
                sig_insttype <= "01";
                sig_opcode <= "001000";
                sig_readdata1 <= (others => '0');
                sig_imm <= (others => '0');
                wb_queue(wb_queue_idx) <= 0;

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
    e_insttype  <= sig_insttype;
    e_opcode    <= sig_opcode;
    e_readdata1 <= sig_readdata1;
    e_readdata2 <= sig_readdata2;
    e_imm       <= sig_imm;
end arch;
