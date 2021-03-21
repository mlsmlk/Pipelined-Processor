library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity write_back is

port(   clk     : in std_logic;				-- clock
	mem_res	: in std_logic_vector (31 downto 0);		-- read data from mem stage
	alu_res	: in std_logic_vector (31 downto 0);		-- alu result from ex stage
	mem_flag: in std_logic;				-- MUX flag (1- read mem, 0-read ALU result)
	write_data: out std_logic_vector(31 downto 0)	-- data to write back to send Decode stage
	);

end write_back;

architecture arch of write_back is
begin
process(clk, mem_res, alu_res, mem_flag)
begin
	if rising_edge(clk) then
		case mem_flag is
			when '0' => --If flag is 0 then MUX takes the data in 0, so the result of ALU will be written back
				write_data <= alu_res;
			when '1' => --If flag is 1 then MUX takes the data in 1, so the result of main memory will be written back
				write_data <= mem_res;
		end case;
        end if;
end process;

end arch;