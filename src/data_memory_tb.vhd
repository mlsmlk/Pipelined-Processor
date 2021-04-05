LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY data_memory_tb IS
END data_memory_tb;

ARCHITECTURE behaviour OF data_memory_tb IS
COMPONENT data_memory IS
	port (
		clk: in std_logic;
		reset: in std_logic;
		
		-- from execute stage
		alu_in: in std_logic_vector (31 downto 0);	-- result of alu (address part in diagram)
		mem_in: in std_logic_vector (31 downto 0);	-- read data 2 from execute stage (write data part in diagram)
		readwrite_flag: in std_logic_vector (1 downto 0); --flag to determine if the op code is related to memory ("01" = read, "10" = write, "00" = neither)

		--to write back stage
		mem_res	: out std_logic_vector (31 downto 0);	-- read data from mem stage
		alu_res	: out std_logic_vector (31 downto 0);	-- alu result from ex stage
		mem_flag: out std_logic;			-- mux flag (1- read mem, 0-read alu result)
	
		--memory signals
		m_addr : out integer range 0 to 8192-1;
		m_read : out std_logic;
		m_readdata : in std_logic_vector (31 downto 0);
		m_write : out std_logic;
		m_writedata : out std_logic_vector (31 downto 0);
		m_waitrequest : in std_logic
	);
end COMPONENT;

COMPONENT memory IS
	GENERIC(
		ram_size : INTEGER := 8192;
        	mem_delay : time := 10 ns;
        	clock_period : time := 1 ns
	);
        PORT (
          	clock: IN STD_LOGIC;
    		writedata: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
    		address: IN INTEGER RANGE 0 TO ram_size-1;
   		memwrite: IN STD_LOGIC;
    		memread: IN STD_LOGIC;
    		readdata: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
    		waitrequest: OUT STD_LOGIC
        );
 END COMPONENT;

    	signal clk : std_logic := '0';
	signal reset : std_logic := '0';
    	constant clk_period : time := 1 ns;
    	signal m_addr : integer range 0 to 8192;
	signal m_read : std_logic;
	signal m_readdata : std_logic_vector (31 downto 0);
	signal m_write : std_logic;
	signal m_writedata : std_logic_vector (31 downto 0);
	signal m_waitrequest : std_logic; 

    	signal alu_in: std_logic_vector (31 downto 0);	
    	signal mem_in: std_logic_vector (31 downto 0);	
    	signal readwrite_flag: std_logic_vector (1 downto 0);
    	signal mem_res:std_logic_vector (31 downto 0);	
    	signal alu_res:std_logic_vector (31 downto 0);	
    	signal mem_flag:std_logic;			

BEGIN
dut: data_memory
	port map(
    		clk => clk,
		reset => reset,
		alu_in => alu_in,	
		mem_in => mem_in,
		readwrite_flag => readwrite_flag,
		mem_res	=> mem_res,
		alu_res	=> alu_res,
		mem_flag => mem_flag,	

		m_addr => m_addr,
   		m_read => m_read,
    		m_readdata => m_readdata,
    		m_write => m_write,
    		m_writedata => m_writedata,
    		m_waitrequest => m_waitrequest
		);

MEM : memory
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
begin

-- initialize the input of memory
mem_in <= "11111111111111111111111111111111";

-- put your tests here
--REPORT "Test case 1: Write Flag";
readwrite_flag <= "10";
alu_in <= "00000000000000000000000000000001";
wait until rising_edge(m_waitrequest);
ASSERT (mem_flag = '1') REPORT "MEM FLAG ERROR" SEVERITY ERROR;
ASSERT (alu_res = "00000000000000000000000000000001") REPORT "ALU RES ERROR" SEVERITY ERROR;
ASSERT (mem_res = "11111111111111111111111111111111") REPORT "MEM RES ERROR" SEVERITY ERROR;

--REPORT "Test case 2: Read Flag";
--readwrite_flag <= "01";
--alu_in <= "00000000000000000000000000000001";
--WAIT FOR 1 * clk_period;
--ASSERT (mem_flag = '1') REPORT "MEM FLAG ERROR" SEVERITY ERROR;
--ASSERT (alu_res = "00000000000000000000000000000001") REPORT "ALU RES ERROR" SEVERITY ERROR;
--ASSERT (mem_res = "11111111111111111111111111111111") REPORT "MEM RES ERROR" SEVERITY ERROR;


--REPORT "Test case 3: Non mem related";
--readwrite_flag <= "00";
--alu_in <= "00000000000000000000000000001111";
--WAIT FOR 1 * clk_period;
--ASSERT (mem_flag = '0') REPORT "MEM FLAG ERROR" SEVERITY ERROR;
--ASSERT (alu_res = "00000000000000000000000000001111") REPORT "ALU RES ERROR" SEVERITY ERROR;
--ASSERT (mem_res = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX") REPORT "MEM RES ERROR" SEVERITY ERROR;

 end process;
end;
