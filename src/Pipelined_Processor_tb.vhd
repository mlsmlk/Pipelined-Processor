library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_processor_tb is
end pipelined_processor_tb;

architecture behavior of pipelined_processor_tb is
    -- Pipelined processor component
    component pipelined_processor is
        port(
            --- INPUTS ---
            --- INPUTS ---
            -- Clock
            clock : in std_logic;
            -- Reset the processor (PC starts at 0)
            reset : in std_logic;
            -- Tell the processor to print out the memory and register values
            write_to_file : in std_logic
        );
    end component;

    --- TEST SIGNALS ---
    -- Inputs
    signal clock : std_logic := '0';
    constant clock_period : time := 1 ns;
    signal reset : std_logic;
    signal write_to_file : std_logic := '0';

begin
    -- Connect the component to the signals
    proc : pipelined_processor
    port map(
        -- Inputs
        clock,
        reset,
        write_to_file
    );

    -- Drive the clock
    clk_process : process
    begin
        clock <= '1';
        wait for clock_period/2;
        clock <= '0';
        wait for clock_period/2;
    end process;

    -- Run the pipelined processor
    proc_process : process
    begin
        -- Reset the pipeline while the program file is loaded into memory
        reset <= '1';
        wait for clock_period * 3;
        reset <= '0';

        -- Run the processor for 10,000 clock cycles
        wait for clock_period * 10000;

        -- Write the registers and the memory to their respective files
        write_to_file <= '1';
        wait for clock_period;
        write_to_file <= '0';

        -- Wait for the simulation to finish
        wait;
    end process;
end;