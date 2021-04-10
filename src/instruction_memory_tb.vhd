library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instruction_memory_tb is
end instruction_memory_tb;

architecture behavior of instruction_memory_tb is

component memory is 
GENERIC(
    ram_size : INTEGER := 32768;
    mem_delay : time := 10 ns;
    clock_period : time := 1 ns
);
PORT (
    clock: IN STD_LOGIC;
    writedata: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
    address: IN INTEGER RANGE 0 TO ram_size-1;
    memwrite: IN STD_LOGIC;
    memread: IN STD_LOGIC;
    readdata: OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
    waitrequest: OUT STD_LOGIC
);
end component;
	
-- test signals 
signal program_counter : std_logic_vector(31 downto 0) := 00000000000000000000000000000000;
signal mem_read : std_logic := '0'; -- High when reading from main memory
signal mem_addr : integer range 0 to ram_size-1; -- Address of target byte in memory
signal reset_to_decode: std_logic := '0';
signal mem_readdata : std_logic_vector(31 downto 0);

-- Assert will be used many times so package and track the amount of errors
procedure assert_equal(actual, expected : in std_logic_vector(31 downto 0); error_count : inout integer) is
    begin
        if (actual /= expected) then
            error_count := error_count + 1;
            report "Error count: " & integer'image(error_count);
        end if;
        assert (actual = expected) report "Expected " & integer'image(to_integer(signed(expected))) & " but the data was " & integer'image(to_integer(signed(actual))) severity error;
    end assert_equal;

begin

-- Connect the components which we instantiated above to their
-- respective signals

dut : instruction_memory
port map (
    clock => clk,
    writedata => m_writedata,
    address => m_addr,
    memwrite => m_write,
    memread => m_read,
    readdata => m_readdata,
    waitrequest => m_waitrequest
);
				

clk_process : process
begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
end process;

test_process : process
    variable error_count : integer := 0;
begin

    Report "Starting test bench";
	WAIT FOR clk_period;
    WAIT FOR clk_period;

    -- Test case 1: Read the first instruction
    report "Test 1: Write tag equal invalid clean";
    m_read       <= '1';
    m_addr       <= '0';
    wait until falling_edge(m_waitrequest);
    m_read      <= '0';
    assert_equals(m_readdata, '00100000001000010000000000000001')
    

    Report "Testbench complete";
    
end process;
	
end;