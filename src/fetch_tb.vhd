library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fetch_tb is
end fetch_tb;

architecture behavior of fetch_tb is

component fetch is
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
end component;

-- test signals
signal clk : std_logic := '0';
constant clk_period : time := 1 ns;
signal jump_address : std_logic_vector(31 downto 0) := (others => '0');
signal jump_flag : std_logic;
signal stall_pipeline : std_logic;
signal reset_out : std_logic;
signal program_counter : std_logic_vector(31 downto 0) := "00000000000000000000000000000000";
signal reset_to_decode: std_logic := '0';
signal instruction : std_logic_vector(31 downto 0) := (others => '0');

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
-- respective signals.
dut: fetch 
port map(
    clk,
    jump_address,
    jump_flag,
    stall_pipeline,
    instruction,
    program_counter,
    reset_out
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
    variable pc_temp : std_logic_vector (31 downto 0);
begin
    wait until rising_edge(clk);

    Report "Starting test bench";

    pc_temp := (others=>'0');
		
    ASSERT (program_counter = pc_temp) REPORT "PC is not initialized to 0!" Severity ERROR; --PC = 0
		
    -- Wait 
    wait for clk_period;
    
    ASSERT (instruction = "00100000000010100000000000000100") REPORT "PC = 0 is wrong" SEVERITY ERROR;

    Report "Testbench complete";
    
end process;
	
end;