library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute is
	GENERIC(
		ram_size : INTEGER := 32768;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
    port(
        --- INPUTS ---
		  -- From the Decode state
		  e_readdata1 : in std_logic_vector(31 downto 0);
        e_readdata2 : in std_logic_vector(31 downto 0);
		  e_se_ivalue : in std_logic_vector(31 downto 0);
        e_opcode : in std_logic_vector(5 downto 0);
        e_forward : in std_logic; -- Also to be forwarded to the memory stage
        e_readwrite : in std_logic_vector(1 downto 0) -- "01" = read, "10" = write, "00" = neither
        -- Clock
        clock : in std_logic;
        -- From the Fetch stage
        f_reset : in std_logic;
		  f_nextPC : in std_logic_vector(31 downto 0);
        
        --- OUTPUTS ---
        -- To the Memory stage
        alu_result : out std_logic_vector(31 downto 0);
        writedata : out std_logic_vector(31 downto 0);
		  readdata: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
        memwrite: OUT STD_LOGIC;
		  memread: OUT STD_LOGIC;
		  branch_taken: OUT STD_LOGIC;
		  branch_target_addr: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
    );
end execute;

architecture arch of execute is
    -- Constants and signals
begin

    execute_proc: process (clock, f_reset)
        -- Variables
		  variable result : std_logic_vector(31 downto 0);
    begin
        if (f_reset = '1') or (now < 1 ps) then
            -- Either starting up or a branch was taken so the pipeline must be flushed

        elsif (rising_edge(clock)) then
            -- Process all the decode stuff
				
				-- 1. Shift left 2
				
				-- 2. Mux
								
				-- 3. ALU: explain the opcode, do operation on data1 and data2, 
				-- get the readdata or writedata
				-- branch flag and branch addr
				
				-- 4. Get PC counter: PC+4
				
				
        end if;
    end process;

end arch;
