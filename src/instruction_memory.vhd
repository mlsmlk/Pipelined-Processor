-- Adapted from memory.vhd from cache project
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

ENTITY instruction_memory IS
	GENERIC(
		ram_size : INTEGER := 32768;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
	PORT (
		clock: IN STD_LOGIC;
		writedata: IN STD_LOGIC_VECTOR (31 downto 0);
		address: IN INTEGER RANGE 0 TO ram_size-1;
		memwrite: IN STD_LOGIC;
		memread: IN STD_LOGIC;
		readdata: OUT STD_LOGIC_VECTOR (31 downto 0);
		waitrequest: OUT STD_LOGIC
	);
END instruction_memory;

ARCHITECTURE rtl OF instruction_memory IS
	TYPE MEM IS ARRAY(ram_size-1 downto 0) OF STD_LOGIC_VECTOR(7 downto 0);
	SIGNAL ram_block: MEM;
	SIGNAL read_address_reg: INTEGER RANGE 0 to ram_size-1;
	SIGNAL write_waitreq_reg: STD_LOGIC := '1';
	SIGNAL read_waitreq_reg: STD_LOGIC := '1';
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
                ram_block(line_counter) <= line_data(7 downto 0);
                ram_block(line_counter + 1) <= line_data(15 downto 8);
                ram_block(line_counter + 2) <= line_data(23 downto 16);
                ram_block(line_counter + 3) <= line_data(31 downto 24);
                line_counter := line_counter + 4;
            END LOOP;
            file_close(instructions_file);
		end if;

		--This is the actual synthesizable SRAM block
		IF (clock'event AND clock = '1') THEN
			IF (memwrite = '1') THEN
				ram_block(address) <= writedata(7 downto 0);
				ram_block(address + 1) <= writedata(15 downto 8);
				ram_block(address + 2) <= writedata(23 downto 16);
				ram_block(address + 3) <= writedata(31 downto 24);
			END IF;
		read_address_reg <= address;
		END IF;
    END PROCESS;
    -- Read 4 bytes at a time
    readdata(7 downto 0) <= ram_block(read_address_reg);
    readdata(15 downto 8) <= ram_block(read_address_reg + 1);
    readdata(23 downto 16) <= ram_block(read_address_reg + 2);
    readdata(31 downto 24) <= ram_block(read_address_reg + 3);


	--The waitrequest signal is used to vary response time in simulation
	--Read and write should never happen at the same time.
	waitreq_w_proc: PROCESS (memwrite)
	BEGIN
		IF(memwrite'event AND memwrite = '1')THEN
			write_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;

		END IF;
	END PROCESS;

	waitreq_r_proc: PROCESS (memread)
	BEGIN
		IF(memread'event AND memread = '1')THEN
			read_waitreq_reg <= '0' after mem_delay, '1' after mem_delay + clock_period;
		END IF;
	END PROCESS;
	waitrequest <= write_waitreq_reg and read_waitreq_reg;


END rtl;
