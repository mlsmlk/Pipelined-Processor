library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity data_memory is
	generic (
		ram_size : integer := 16384	
	);
	port (
		clock : in std_logic;

		-- from execute stage
		alu_in : in std_logic_vector (31 downto 0); 		-- result of alu (address part in diagram)
		mem_in : in std_logic_vector (31 downto 0); 		-- read data 2 from execute stage (write data part in diagram)
		readwrite_flag : in std_logic_vector (1 downto 0); 	--flag to determine if the op code is related to memory ("01" = read, "10" = write, "00" = neither)
		write_file_flag : in std_logic := '0'; 			--flag to indicate the commands are finished and the memory can be written into file

		--to write back stage
		mem_res : out std_logic_vector (31 downto 0); 		-- read data from mem stage
		mem_flag : out std_logic; 				-- mux flag (1- read mem, 0-read alu result)
		alu_res : out std_logic_vector (31 downto 0) 		-- result of alu
	);
end entity;

architecture rtl of data_memory is
	type MEM is array(ram_size - 1 downto 0) of STD_LOGIC_VECTOR(31 downto 0);	-- define ram 
begin
	mem_process : process (clock)
		-- the design requires to write and read the data in one clock cycle. 
		-- For this reaons, variables are used instead of signals so that, necessary information cen be updated simultaneously
		variable ram_block : MEM; -- define type of the memory
		-- memory variables
		variable m_addr : integer range 0 to ram_size - 1;	-- address to write/read
		variable m_write : std_logic;				-- write flag
		variable m_writedata : std_logic_vector (31 downto 0);	-- data needs to be written into memory
		file memoryFile : text open write_mode is "memory.txt"; -- memory.txt initialization
		variable outLine : line; 
	begin
		m_addr := to_integer(unsigned(alu_in));
		--Cheap trick used in previous assignment to initialize the SRAM in simulation
		if (now < 1 ps) then
			for i in 0 to ram_size - 1 loop

				ram_block(i) := std_logic_vector(to_unsigned(i, 32));
	
			end loop;
		end if;

		if (clock'EVENT and clock = '1') then
			if readwrite_flag = "01" then -- If the request is read
				mem_flag <= '1'; -- deinfe memory related flag to 1
				m_write := '0';	-- define memory variables appropiate to read
				
			elsif readwrite_flag = "10" then -- If the request is write
				mem_flag <= '1'; -- deinfe memory related flag to 1
				m_write := '1';	-- define memory variables appropiate to write
				m_writedata := mem_in; -- define the data needs to be written

			else --If the request is else
				mem_flag <= '0'; -- there nothing related to memory
				m_write := 'X'; -- no read/write flag
				mem_res <= "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX";
			end if;

			if (m_write = '1') then			 -- if there is a write request
				ram_block(m_addr) := m_writedata;-- define the data into given address of the memory
			end if;
			mem_res <= ram_block(m_addr);		-- read the data from given address (it also confirms that the requested data is succesfully written in the write case)
 			
			alu_res <= alu_in;
		end if;
		if (write_file_flag = '1') then			--if the proccess is over,all read/write requests are finished
			for index in 0 to ram_size-1 loop
			if(index mod 4 = 0) then
			write(outLine, ram_block(index));	-- write the data in each address of the ram into new line
			writeline(memoryFile, outLine);
			end if;
		end loop;
	end if;
	end process;

end rtl;
