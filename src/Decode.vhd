library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decode is
    port(
        --- INPUTS ---
        -- Clock
        clock : in std_logic;
        -- From the Fetch stage
        f_instruction : in std_logic_vector(31 downto 0); -- The instruction to be parsed
        f_reset : in std_logic; -- Reset flag
        -- From the Writeback stage
        w_regdata : in std_logic_vector(31 downto 0); -- Data to be written back to a register

        --- OUTPUTS ---
        -- To the Execute stage
        e_opcode : out std_logic_vector(5 downto 0); -- Parse and forward the op code
        e_readdata1 : out std_logic_vector(31 downto 0); -- Data 1 (from register)
        e_readdata2 : out std_logic_vector(31 downto 0); -- Data 2 (from register)
        e_se_ivalue : out std_logic_vector(31 downto 0); -- Immediate value
        e_forward : out std_logic -- Also to be forwarded to the memory stage
    );
end decode;

architecture arch of decode is
    ----- CONSTANTS -----
    constant NUM_REGISTERS: natural := 32;

    ----- TYPE DEFINITIONS -----
    type writeback_queue is array(0 to 2) of natural range 0 to NUM_REGISTERS - 1;
    type register_file is array(0 to NUM_REGISTERS - 1) of std_logic_vector(31 downto 0);

    ----- SIGNALS -----
    -- Register file
    signal registers: register_file;
    -- For writing back
    signal wb_queue: writeback_queue; -- Stores which register will be written back to next
    signal wb_queue_idx: natural range 0 to 2 := 0;
begin

    decode_proc: process (clock, f_reset)
        ----- VARIABLES -----
        -- Replica of the register file to help simplify the write back process
        variable registers_var : register_file;
        -- Parts of the instruction
        variable opcode : std_logic_vector(5 downto 0);
        variable reg1_idx : natural range 0 to NUM_REGISTERS - 1; -- Operand register 1 index
        variable reg1_data : std_logic_vector(31 downto 0); -- Operand register 1 data
        variable reg2_idx : natural range 0 to NUM_REGISTERS - 1; -- Operand register 2 index
        variable reg2_data : std_logic_vector(31 downto 0); -- Operand register 2 data
        variable imm : std_logic_vector(15 downto 0); -- Immediate value
    begin
        -- Create an alias of the register file to allow the register file to be changed within CC
        registers_var := registers;

        if (f_reset = '1') or (now < 1 ps) then
            -- Either starting up or a branch was taken so the pipeline must be flushed
            -- Set register 0 to have a value of 0
            registers(0) <= 0;

        elsif (rising_edge(clock)) then
            -- Perform a writeback operation if necessary
            if (wb_queue(wb_queue_idx) /= 0) then
                registers(wb_queue(wb_queue_idx)) <= w_regdata;
                -- Increase the circular index
                if (wb_queue_idx == 2) then
                    wb_queue_idx <= 0;
                else
                    wb_queue_idx <= wb_queue_idx + 1;
                end if;
            end if;

            -- Parse the instruction
            opcode := f_instruction(31 downto 26);
            reg1_idx := to_integer(unsigned(f_instruction(25 downto 21)));
            reg2_idx := to_integer(unsigned(f_instruction(20 downto 16)));
            imm := f_instruction(15 downto 0);

            -- Load the data from the appropriate registers
            reg1_data := registers_var(reg1_idx);
            reg2_data := registers_var(reg2_idx);

            -- Add the target register to the queue
        end if;

        -- Update the true register file with the temporary register file
        registers <= registers_var;
    end process;
end arch;
