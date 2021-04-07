library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_memory is
	generic (
		ram_size : integer := 8192;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
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
		alu_res : out std_logic_vector (31 downto 0); -- result of alu
 
		--memory signals
		m_addr : out integer range 0 to ram_size - 1; 
		m_read : out std_logic; 
		m_readdata : in std_logic_vector (31 downto 0);
		m_write : out std_logic;
		m_writedata : out std_logic_vector (31 downto 0);
		m_waitrequest : in std_logic
	);
end data_memory;

architecture rtl of data_memory is

	--Define states
	type states is (idle, mm_write, mm_read, mm_wait);
	signal state : states;

begin
	mem_process : process (reset, clk, alu_in, mem_in, readwrite_flag, m_waitrequest, state)
	begin
		alu_res <= alu_in;

		if (reset = '1') then
			state <= idle;

		elsif (rising_edge(clk)) then
			case state is
				when idle => 
					if readwrite_flag = "01" then -- If the request is read
						mem_flag <= '1'; -- deinfe memory related flag to 1
						m_write <= 'X';
						m_read <= 'X';
						state <= mm_read; -- switch to cache read state
					elsif readwrite_flag = "10" then -- If the request is write
						mem_flag <= '1'; -- deinfe memory related flag to 1
						state <= mm_write; -- switch to cache write state
					else --If the request is else
						mem_flag <= '0'; -- there nothing related to memory
						m_write <= 'X';
						m_read <= 'X';
						state <= idle; -- stay in idle state
					end if; 
 
				when mm_read => 
					if m_waitrequest = '1' then --If the main memory is ready for request
						m_addr <= to_integer(unsigned(alu_in)); -- get address from ALU
						m_write <= '0'; 
						m_read <= '1';
						state <= mm_wait; 
					else
						state <= mm_read; --wait main memory to be ready
					end if;
 
				when mm_wait => 
					if m_waitrequest = '0' then
						mem_res <= m_readdata;
						state <= idle;
					else
						state <= mm_wait;
					end if;

				when mm_write => 
					if m_waitrequest = '1' then --If the word count reaches to the limit (4 word per block 
						m_addr <= to_integer(unsigned(alu_in));
						m_write <= '1';
						m_read <= '0';
						m_writedata <= mem_in;
						state <= mm_read;
					else --wait until main memory is ready for receving request
						m_write <= '0'; 
						state <= mm_write;
					end if;
			end case;
		end if;
	end process;
end rtl;
