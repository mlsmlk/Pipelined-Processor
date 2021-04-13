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

-- Assert will be used many times so package and track the amount of errors
procedure assert_equal(actual, expected : in std_logic_vector(31 downto 0); error_count : inout integer) is
    begin
        if (actual /= expected) then
            error_count := error_count + 1;
            report "Error count: " & integer'image(error_count);
        end if;
        assert (actual = expected) report "Expected " & integer'image(to_integer(unsigned(expected))) & " but the data was " & integer'image(to_integer(unsigned(actual))) severity error;
    end assert_equal;

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
    variable error_count : integer := 0;
begin

    Report "Starting test bench";
    wait until rising_edge(clk);

    -- Test case 1: Read the first instruction
    report "Test 1: Read Instruction 1";
    address       <= std_logic_vector(to_unsigned(0*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00100000000010100000000000000100", error_count);

    -- Test case 2: Read second instruction @ address 4
    report "Test 2: Read Instruction 2";
    address       <= std_logic_vector(to_unsigned(1*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00100000000000010000000000000001", error_count);

    -- Test case 3: Read sixth instruction @ address 24
    report "Test 3: Read Instruction 6";
    address       <= std_logic_vector(to_unsigned(5*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00100000010000110000000000000000", error_count);

    -- Test case 4: Read 14th instruction
    report "Test 4: Read Instruction 14";
    address       <= std_logic_vector(to_unsigned(13*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00010101010000001111111111110111", error_count);

     -- Test case 5: Read 15th (last) instruction
    report "Test 5: Read Instruction 15 (last)";
    address       <= std_logic_vector(to_unsigned(14*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00010001011010111111111111111111", error_count);

     -- Test case 6: Read ninth instruction
     report "Test 5: Read Instruction 15 (last)";
     address       <= std_logic_vector(to_unsigned(8*4, 32));
     wait until rising_edge(clk);
     assert_equal(readdata, "00000001010011110000000000011000", error_count);

    -- Test case 7: Read instruction past program limit
    report "Test 7: Read Instruction past program limit";
    address       <= std_logic_vector(to_unsigned(25*4, 32));
    wait until rising_edge(clk);
    assert_equal(readdata, "00000001010011110000000000011000", error_count);

    Report "Testbench complete";
    report "Error count: " & integer'image(error_count);
    wait;
end process;
	
end;