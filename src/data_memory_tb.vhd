library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_memory_tb is
end data_memory_tb;

architecture behaviour of data_memory_tb is
	component data_memory is
		port (
			clk : in std_logic;
			reset : in std_logic;
 
			-- from execute stage
			alu_in : in std_logic_vector (31 downto 0); -- result of alu (address part in diagram)
			mem_in : in std_logic_vector (31 downto 0); -- read data 2 from execute stage (write data part in diagram)
			readwrite_flag : in std_logic_vector (1 downto 0); --flag to determine if the op code is related to memory ("01" = read, "10" = write, "00" = neither)

			--to write back stage
			mem_res : out std_logic_vector (31 downto 0); -- read data from mem stage
			mem_flag : out std_logic; -- mux flag (1- read mem, 0-read alu result)
			alu_res : out std_logic_vector (31 downto 0); 
 
			--memory signals
			m_addr : out integer range 0 to 8192 - 1;
			m_read : out std_logic;
			m_readdata : in std_logic_vector (31 downto 0);
			m_write : out std_logic;
			m_writedata : out std_logic_vector (31 downto 0);
			m_waitrequest : in std_logic
		);
	end component;

	component memory is
		generic (
			ram_size : integer := 8192;
			mem_delay : time := 10 ns;
			clock_period : time := 1 ns
		);
		port (
			clock : in STD_LOGIC;
			writedata : in STD_LOGIC_VECTOR (31 downto 0);
			address : in integer range 0 to ram_size - 1;
			memwrite : in STD_LOGIC;
			memread : in STD_LOGIC;
			readdata : out STD_LOGIC_VECTOR (31 downto 0);
			waitrequest : out STD_LOGIC
		);
	end component;

	signal clk : std_logic := '0';
	signal reset : std_logic := '0';
	constant clk_period : time := 1 ns;
	signal m_addr : integer range 0 to 8192;
	signal m_read : std_logic;
	signal m_readdata : std_logic_vector (31 downto 0);
	signal m_write : std_logic;
	signal m_writedata : std_logic_vector (31 downto 0);
	signal m_waitrequest : std_logic;

	signal alu_in : std_logic_vector (31 downto 0); 
	signal mem_in : std_logic_vector (31 downto 0); 
	signal readwrite_flag : std_logic_vector (1 downto 0);
	signal mem_res : std_logic_vector (31 downto 0); 
	signal alu_res : std_logic_vector (31 downto 0); 
	signal mem_flag : std_logic; 

begin
	dut : data_memory
	port map(
		clk => clk, 
		reset => reset, 
		alu_in => alu_in, 
		mem_in => mem_in, 
		readwrite_flag => readwrite_flag, 
		mem_res => mem_res, 
		alu_res => alu_res, 
		mem_flag => mem_flag, 

		m_addr => m_addr, 
		m_read => m_read, 
		m_readdata => m_readdata, 
		m_write => m_write, 
		m_writedata => m_writedata, 
		m_waitrequest => m_waitrequest
	);

	MEM : memory
	port map(
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
	begin
		-- initialize the input of memory
		-- put your tests here
		report "Test CASE 1: Write Flag - VARIABLE 1";
		readwrite_flag <= "10";
		mem_in <= "11111111111111111111111111111111";
		alu_in <= "00000000000000000000000000000001";
		wait until rising_edge(m_waitrequest);
		assert (mem_flag = '1') report "MEM FLAG ERROR" severity ERROR;
		assert (mem_res = "11111111111111111111111111111111") report "MEM RES ERROR" severity ERROR;
		assert (alu_res = "00000000000000000000000000000001") report "ALU RES ERROR" severity ERROR;

		report "Test CASE 2: Write Flag - VARIABLE 2";
		readwrite_flag <= "10";
		mem_in <= "11111111111111111111111111111000";
		alu_in <= "00000000000000000000000000001111";
		wait until rising_edge(m_waitrequest);
		assert (mem_flag = '1') report "MEM FLAG ERROR" severity ERROR;
		assert (mem_res = "11111111111111111111111111111000") report "MEM RES ERROR" severity ERROR;
		assert (alu_res = "00000000000000000000000000001111") report "ALU RES ERROR" severity ERROR;

		report "Test CASE 3: Non mem related ";
		readwrite_flag <= "00";
		alu_in <= "00000000000000000000000000001111";
		wait until rising_edge(m_waitrequest);
		assert (mem_flag = '0') report "MEM FLAG ERROR" severity ERROR;

		report "Test CASE 4: Read Flag - VARIABLE 1";
		readwrite_flag <= "01";
		alu_in <= "00000000000000000000000000000001";
		wait until rising_edge(m_waitrequest);
		assert (mem_flag = '1') report "MEM FLAG ERROR" severity ERROR;
		assert (mem_res = "11111111111111111111111111111111") report "MEM RES ERROR" severity ERROR;
		assert (alu_res = "00000000000000000000000000000001") report "ALU RES ERROR" severity ERROR;

		report "Test CASE 5: Read Flag - VARIABLE 2";
		readwrite_flag <= "01";
		alu_in <= "00000000000000000000000000001111";
		wait until rising_edge(m_waitrequest);
		assert (mem_flag = '1') report "MEM FLAG ERROR" severity ERROR;
		assert (mem_res = "11111111111111111111111111111000") report "MEM RES ERROR" severity ERROR;
		assert (alu_res = "00000000000000000000000000001111") report "ALU RES ERROR" severity ERROR;

		report "--------------END-----------------";
		wait;
	end process;
end;
