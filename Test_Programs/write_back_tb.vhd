library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wb_tb is
end wb_tb;

architecture behavior of wb_tb is

component write_back is

port(   clk     : in std_logic;				-- clock
	mem_res	: in std_logic_vector (31 downto 0);	-- read data from mem stage
	alu_res	: in std_logic_vector (31 downto 0);	-- alu result from ex stage
	mem_flag: in std_logic;				-- MUX flag (1- read mem, 0-read ALU result)
	write_data: out std_logic_vector(31 downto 0)	-- data to write back to send Decode stage
);

end component;

-- test signals 
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;

signal mem_res	: std_logic_vector (31 downto 0);
signal alu_res	: std_logic_vector (31 downto 0);
signal mem_flag: std_logic;
signal write_data: std_logic_vector(31 downto 0);

begin

-- Connect the components which we instantiated above to their
-- respective signals.
dut: write_back 
port map(
    clk => clk,
    mem_res => mem_res,
    alu_res => alu_res,
    mem_flag => mem_flag,
    write_data => write_data
);

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
begin
-- initialize the result of memory and alu
mem_res <= "11111111111111111111111111111111";
alu_res <= "00000000000000000000000000000000";

-- put your tests here
REPORT "Test case 1: Writeback the result of ALU stage";
mem_flag <= '0';
WAIT FOR 1 * clk_period;
ASSERT (write_data = "00000000000000000000000000000000") REPORT "ALU RESULT" SEVERITY ERROR;

REPORT "Test case 2: Writeback the result of MEM stage";
mem_flag <= '1';
WAIT FOR 1 * clk_period;
ASSERT (write_data = "11111111111111111111111111111111") REPORT "MEM RESULT" SEVERITY ERROR;

REPORT "Test case 3: Wrong MUX Values";
mem_flag <= 'X';
WAIT FOR 1 * clk_period;
ASSERT (write_data = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") REPORT "WRONG MUX VALUE" SEVERITY ERROR;
	
end process;
	
end;