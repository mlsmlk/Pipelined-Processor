--Adapted from Example 12-15 of Quartus Design and Synthesis handbook
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory is
	generic (
		ram_size : integer := 8192;
		mem_delay : time := 1 ns;
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
end memory;

architecture rtl of memory is
	type MEM is array(ram_size - 1 downto 0) of STD_LOGIC_VECTOR(31 downto 0);
	signal ram_block : MEM;
	signal read_address_reg : integer range 0 to ram_size - 1;
	signal write_waitreq_reg : STD_LOGIC := '1';
	signal read_waitreq_reg : STD_LOGIC := '1';
begin
	--This is the main section of the SRAM model
	mem_process : process (clock)
	begin
		--This is a cheap trick to initialize the SRAM in simulation
		if (now < 1 ps) then
			for i in 0 to ram_size - 1 loop
				ram_block(i) <= std_logic_vector(to_unsigned(i, 32));
			end loop;
		end if;

		--This is the actual synthesizable SRAM block
		if (clock'EVENT and clock = '1') then
			if (memwrite = '1') then
				ram_block(address) <= writedata;
			end if;
			read_address_reg <= address;
		end if;
	end process;
	readdata <= ram_block(read_address_reg);
	--The waitrequest signal is used to vary response time in simulation
	--Read and write should never happen at the same time.
	waitreq_w_proc : process (memwrite)
	begin
		if (memwrite'EVENT and memwrite = '1') then
			write_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;

		end if;
	end process;

	waitreq_r_proc : process (memread)
	begin
		if (memread'EVENT and memread = '1') then
			read_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		end if;
	end process;
	waitrequest <= write_waitreq_reg and read_waitreq_reg;
end rtl;
