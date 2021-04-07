library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity data_memory is
	generic (
		ram_size : integer := 8192	
	);
	port (
		clock : in std_logic;

		-- from execute stage
		alu_in : in std_logic_vector (31 downto 0); -- result of alu (address part in diagram)
		mem_in : in std_logic_vector (31 downto 0); -- read data 2 from execute stage (write data part in diagram)
		readwrite_flag : in std_logic_vector (1 downto 0); --flag to determine if the op code is related to memory ("01" = read, "10" = write, "00" = neither)
		write_file_flag : in std_logic := '0'; --flag to indicate the commands are finished and the memory can be written into file

		--to write back stage
		mem_res : out std_logic_vector (31 downto 0); -- read data from mem stage
		mem_flag : out std_logic; -- mux flag (1- read mem, 0-read alu result)
		alu_res : out std_logic_vector (31 downto 0) -- result of alu
	);
end entity;

architecture rtl of data_memory is

	type MEM is array(ram_size - 1 downto 0) of STD_LOGIC_VECTOR(31 downto 0);
	signal ram_block : MEM;
	signal read_address_reg : integer range 0 to ram_size - 1;
	signal write_waitreq_reg : STD_LOGIC := '1';
	signal read_waitreq_reg : STD_LOGIC := '1';
	signal m_addr : integer range 0 to ram_size - 1;
	signal m_read : std_logic;
	signal m_readdata : std_logic_vector (31 downto 0);
	signal m_write : std_logic;
	signal m_writedata : std_logic_vector (31 downto 0);
	signal m_waitrequest : std_logic;
	signal initialization_flag : std_logic := '0';
	 
begin
	mem_process : process (clock)
		file memoryFile : text open write_mode is "memory.txt";
		variable outLine : line; 
	begin
		m_addr <= to_integer(unsigned(alu_in));
		--This is a cheap trick to initialize the SRAM in simulation
		if (now < 1 ps) then
			for i in 0 to ram_size - 1 loop
				ram_block(i) <= std_logic_vector(to_unsigned(i, 32));
			end loop;
			initialization_flag <= '1';
		end if;

		--This is the actual synthesizable SRAM block
		if (clock'EVENT and clock = '1') then
			if readwrite_flag = "01" then -- If the request is read
				mem_flag <= '1'; -- deinfe memory related flag to 1
				m_write <= '0';
				m_read <= '1';

			elsif readwrite_flag = "10" then -- If the request is write
				mem_flag <= '1'; -- deinfe memory related flag to 1
				m_write <= '1';
				m_read <= '0';
				m_writedata <= mem_in;

			else --If the request is else
				mem_flag <= '0'; -- there nothing related to memory
				m_write <= 'X';
				m_read <= 'X';
				mem_res <= "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
			end if;

			if (m_write = '1') then
				ram_block(m_addr) <= m_writedata;
				initialization_flag <= '0';
			end if;
			read_address_reg <= m_addr;
 
			if (initialization_flag = '0') then
				mem_res <= ram_block(read_address_reg);
 
			end if;
			alu_res <= alu_in;
		end if;
		if (write_file_flag = '1') then
			for index in 0 to ram_size-1 loop
			write(outLine, index);
			writeline(memoryFile, outLine);
			write(outLine, ram_block(index));
			writeline(memoryFile, outLine); 
		end loop;
	end if;
	end process;

end rtl;
