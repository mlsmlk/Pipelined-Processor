library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch is
    generic(
	ram_size : INTEGER := 32768
    );
    port(
        --- INPUTS ---
        -- Clock + PC
        clock : in std_logic;
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
    signal reset_to_decode: std_logic := '0';
    signal im_readdata : std_logic_vector(31 downto 0);

    component instruction_memory
        PORT (
            clock: in std_logic;
            address: in std_logic_vector(31 downto 0);
            readdata: out std_logic_vector(31 downto 0)
        );
    end component;

begin

    IM: instruction_memory
    port map (
        clock;
        program_counter;
        readdata
    );

    fetch_process: process (clock, reset)
        -- Variables to be defined
    begin
        if (rising_edge(clock)) then
            -- If we are not stalling then check if we are branching/jumping
            -- If stall, then do nothing
            if (stall_pipeline = '0') then
                -- If jumping, set program counter to new address and get new instruction
                if (jump_flag = '1') then
                    program_counter <= jump_address;
                    reset_to_decode <= '1';
                else
                    -- Increment PC by 4 if no branch
                    program_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(program_counter)) + 4, 32)));
                    reset_to_decode <= '0';
                end if;
            end if;
        end if;
    end process;
    -- Assignment here
    reset_out <= reset_to_decode;
    program_counter_out <= program_counter;
    instruction <= readdata;
end arch;