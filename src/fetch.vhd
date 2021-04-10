library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch is
    generic(
	ram_size : INTEGER := 32768
    );
    port(
        --- INPUTS ---
        -- Clock + Reset + PC
        clock : in std_logic;
        reset : in std_logic; -- Reset necessary?
        program_counter_in : out std_logic_vector(31 downto 0);
        -- Instruction Memory interface
        m_addr : out integer range 0 to ram_size-1;
        m_read : out std_logic;
        m_readdata : in std_logic_vector (7 downto 0);
        m_write : out std_logic;
        m_writedata : out std_logic_vector (7 downto 0);
        m_waitrequest : in std_logic
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
    signal mem_read : std_logic := '0'; -- High when reading from main memory
    signal mem_addr : integer range 0 to ram_size-1; -- Address of target byte in memory
    signal reset_to_decode: std_logic := '0';
    signal mem_readdata : std_logic_vector(31 downto 0);
begin

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
                    program_counter <= program_counter_in;
                    reset_to_decode <= '0';
                    -- If not stalling or branching, return the result of the previous instruction read
                    mem_read <= '0';
                end if;
                -- Check waitrequest, then fetch
                if (m_waitrequest = '0') then
                    mem_addr <= program_counter;
					mem_read <= '1';
                end if;
            end if;
        end if;
    end process;
    -- Assignment here
    reset_out <= reset_to_decode;
    program_counter_out <= program_counter;
    instruction <= m_readdata;
end arch;