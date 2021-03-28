library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decode is
    port(
        --- INPUTS ---
        -- Clock
        clock : in std_logic;
        -- From the Fetch stage
        f_instruction : in std_logic_vector(31 downto 0);
        f_reset : in std_logic;
        -- From the Writeback stage
        w_regdata : in std_logic_vector(31 downto 0);

        --- OUTPUTS ---
        -- To the Execute stage
        e_readdata1 : out std_logic_vector(31 downto 0);
        e_readdata2 : out std_logic_vector(31 downto 0);
        e_se_ivalue : out std_logic_vector(31 downto 0);
        e_opcode : out std_logic_vector(5 downto 0);
        e_forward : out std_logic; -- Also to be forwarded to the memory stage
        e_readwrite : out std_logic_vector(1 downto 0) -- "01" = read, "10" = write, "00" = neither
    );
end decode;

architecture arch of decode is
    -- Constants and signals
begin

    decode_proc: process (clock, f_reset)
        -- Variables
        variable var_opcode : std_logic_vector(5 downto 0);
    begin
        if (f_reset = '1') or (now < 1 ps) then
            -- Either starting up or a branch was taken so the pipeline must be flushed

        elsif (rising_edge(clock)) then
            -- Process all the decode stuff
        end if;
    end process;

end arch;
