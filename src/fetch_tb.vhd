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
end component;

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
-- respective signals.
dut: fetch 
port map(
    clock => clk,
    reset => reset,

    program_counter_in => program_counter_in,

    m_addr => m_addr,
    m_read => m_read,
    m_readdata => m_readdata,
    m_write => m_write,
    m_writedata => m_writedata,
    m_waitrequest => m_waitrequest,

    jump_address => jump_address,
    jump_flag => jump_flag,
    stall_pipeline => stall_pipeline,
    instruction => instruction,
    program_counter_out => program_counter_out,
    reset_out => reset_out
);

MEM : instruction_memory
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

    Report "Testbench complete";
    
end process;
	
end;