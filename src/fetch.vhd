library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch is
    port(
        --- INPUTS ---
        -- Clock + Reset
        clock : in std_logic;
        reset : in std_logic; -- Reset necessary?
        -- From Instruction Memory
        readdata: IN std_logic_vector (31 DOWNTO 0);
        waitrequest: IN std_logic
        -- From Execute stage
        jump_address : in std_logic_vector(31 downto 0);
        jump_flag : in std_logic;
        stall_pipeline : in std_logic;

        --- OUTPUTS ---
        -- To Decode stage
        instruction : out std_logic_vector(31 downto 0);
        program_counter_out : out std_logic_vector(31 downto 0);
        reset_out : out std_logic
    );
end fetch;

architecture arch of fetch is
    -- Constants and signals to be defined
    signal program_counter : std_logic_vector(31 downto 0) := 00000000000000000000000000000000;
begin

    fetch_process: process (clock, reset)
        -- Variables to be defined
    begin
        if (rising_edge(clock)) then
            -- If we are not stalling then check if we are branching
            -- If stall, then do nothing
            if (stall_pipeline = '0') then
                -- If jumping, set program counter to new address and get new instruction
                if (jump_flag = '1') then
                    program_counter <= jump_address;
                end if;
                -- Check waitrequest, then fetch
            end if;
        end if;
    end process;
    -- Assignment here
end arch;