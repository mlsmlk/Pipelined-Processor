library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_memory_tb is
end instruction_memory_tb;

architecture behavior of instruction_memory_tb is

component instruction_memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    address: IN STD_LOGIC_VECTOR (31 downto 0);
    readdata: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
);
end component;

signal clk : std_logic := '0';
constant clk_period : time := 1 ns;
signal address: std_logic_vector (31 downto 0);
signal readdata: STD_LOGIC_VECTOR (31 DOWNTO 0);

begin
    
    --dut => Device Under Test
    dut: instruction_memory GENERIC MAP(
            ram_size => 256
                )
                PORT MAP(
                    clk,
                    address,
                    readdata
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

    Report "Starting test bench";
	WAIT FOR clk_period;
    WAIT FOR clk_period;

    -- Test case 1: Read the first instruction
    report "Test 1: Read Instruction 1";
    address       <= (others=>'0');
    WAIT FOR clk_period;
    --assert (readdata = '00100000001000010000000000000001') report "Test 1 incorrect read value" severity error;

    -- Test case 2: Read second instruction
    report "Test 2: Read Instruction 2";
    address       <= (2 => '1', others=>'0');
    WAIT FOR clk_period;
    --assert (readdata = '00100000000000010000000000000001') report "Test 2 incorrect read value" severity error;

    Report "Testbench complete";
    
end process;
	
end;