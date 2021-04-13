-- Adapted from memory.vhd from cache project
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

ENTITY instruction_memory IS
	GENERIC(
		ram_size : INTEGER := 32768;
		clock_period : time := 1 ns
	);
	PORT (
		clock: IN STD_LOGIC;
		address: IN std_logic_vector (31 downto 0);
		readdata: OUT STD_LOGIC_VECTOR (31 downto 0)
	);
END instruction_memory;

ARCHITECTURE rtl OF instruction_memory IS
	TYPE MEM IS ARRAY(ram_size-1 downto 0) OF STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL ram_block: MEM;
	SIGNAL read_address_reg: INTEGER RANGE 0 to ram_size-1;
	signal lines_in_memory: integer range 0 to ram_size-1;
BEGIN
	--This is the main section of the SRAM model
    mem_process: PROCESS (clock)
    FILE instructions_file : text;
	variable instruction_line : line;
	variable line_data : std_logic_vector(31 downto 0);
	variable line_counter : integer := 0;

	BEGIN
		--This is a cheap trick to initialize the SRAM in simulation
        IF(now < 1 ps)THEN
            -- Open the file, reading from 'program.txt'
            file_open(instructions_file, "program.txt", read_mode);
            while not endfile(instructions_file) LOOP
                -- Read every line and insert it into memory
                readline(instructions_file, instruction_line);
                read(instruction_line, line_data);
                
                -- Memory is byte addressable, but 4 bytes always together
                ram_block(line_counter)		<= line_data(7 downto 0);
                ram_block(line_counter + 1) <= line_data(15 downto 8);
                ram_block(line_counter + 2) <= line_data(23 downto 16);
                ram_block(line_counter + 3) <= line_data(31 downto 24);
                line_counter := line_counter + 4;
            END LOOP;
			file_close(instructions_file);
			lines_in_memory <= line_counter - 4;
		end if;

	END PROCESS;
	
	read_process: process (clock, address)
	begin
		if (to_integer(unsigned(address)) > lines_in_memory) then
			readdata(7 downto 0)	<= ram_block(lines_in_memory);
    		readdata(15 downto 8) 	<= ram_block(lines_in_memory + 1);
    		readdata(23 downto 16)	<= ram_block(lines_in_memory + 2);
			readdata(31 downto 24) 	<= ram_block(lines_in_memory + 3);
		else
    		-- Read 4 bytes at a time
    		readdata(7 downto 0)	<= ram_block(to_integer(unsigned(address)));
    		readdata(15 downto 8) 	<= ram_block(to_integer(unsigned(address)) + 1);
    		readdata(23 downto 16)	<= ram_block(to_integer(unsigned(address)) + 2);
			readdata(31 downto 24) 	<= ram_block(to_integer(unsigned(address)) + 3);
		end if;
	end process;
END rtl;
