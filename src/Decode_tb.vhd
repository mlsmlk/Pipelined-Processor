library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity decode_tb is
end decode_tb;

architecture behavior of decode_tb is
    -- Decode component
    component decode is
        port(
            --- INPUTS ---
            -- Clock --
            clock : in std_logic;

            -- From the Fetch stage --
            -- The instruction to be parsed
            f_instruction : in std_logic_vector(31 downto 0);
            -- Reset flag
            f_reset : in std_logic;
            -- PC + 4
            f_pcplus4 : in std_logic_vector(31 downto 0);

            -- From the Writeback stage --
            -- Data to be written back to a register
            w_regdata : in std_logic_vector(31 downto 0);

            --- OUTPUTS ---
            -- To the Fetch stage --
            -- Signals if the pipeline should be stalled
            f_stall : out std_logic;

            -- To the Execute stage --
            -- Instruction type
            -- "00" = R-type || "01" = I-type || "10" == J-type
            e_insttype : out std_logic_vector(1 downto 0);
            -- opcode for I-type and J-type, or funct for R-type
            e_opcode : out std_logic_vector(5 downto 0);
            -- Data 1
            e_readdata1 : out std_logic_vector(31 downto 0);
            -- Data 2
            e_readdata2 : out std_logic_vector(31 downto 0);
            -- Extended immediate value
            e_imm : out std_logic_vector(31 downto 0);
            -- Signal to Execute to use the forwarded value from Execute
            e_forward_ex : out std_logic;
            -- Indicate which operand the forwarded value from Execute maps to
            -- "10" = readdata1 || "01" = readdata2 || "11" = both
            e_forwardop_ex : out std_logic_vector(1 downto 0);
            -- Signal to Execute to use the forwarded value from Memory
            e_forward_mem : out std_logic;
            -- Indicate which operand the forwarded value from Memory maps to
            -- "10" = readdata1 || "01" = readdata2 || "11" = both
            e_forwardop_mem : out std_logic_vector(1 downto 0)
        );
    end component;
    
    -- Test signals
    -- INPUTS
    signal clock : std_logic := '0';
    constant clock_period : time := 1 ns;
    signal f_instruction : std_logic_vector(31 downto 0);
    signal f_reset : std_logic;
    signal f_pcplus4 : std_logic_vector(31 downto 0);
    signal w_regdata : std_logic_vector(31 downto 0);

    --- OUTPUTS ---
    signal f_stall : std_logic;
    signal e_insttype : std_logic_vector(1 downto 0);
    signal e_opcode : std_logic_vector(5 downto 0);
    signal e_readdata1 : std_logic_vector(31 downto 0);
    signal e_readdata2 : std_logic_vector(31 downto 0);
    signal e_imm : std_logic_vector(31 downto 0);
    signal e_forward : std_logic;
    signal e_forward_ex : std_logic;
    signal e_forwardop_ex : std_logic_vector(1 downto 0);
    signal e_forward_mem : std_logic;
    signal e_forwardop_mem : std_logic_vector(1 downto 0);

begin
    -- Connect the component to the signals
    dec : decode
    port map(
        -- Inputs
        clock => clock,
        f_instruction => f_instruction,
        f_reset => f_reset,
        f_pcplus4 => f_pcplus4,
        w_regdata => w_regdata,
        -- Outputs
        f_stall => f_stall,
        e_insttype => e_insttype,
        e_opcode => e_opcode,
        e_readdata1 => e_readdata1,
        e_readdata2 => e_readdata2,
        e_imm => e_imm,
        e_forward_ex => e_forward_ex,
        e_forwardop_ex => e_forwardop_ex,
        e_forward_mem => e_forward_mem,
        e_forwardop_mem => e_forwardop_mem
    );

    -- Drive the clock
    clk_process : process
    begin
        clock <= '1';
        wait for clock_period/2;
        clock <= '0';
        wait for clock_period/2;
    end process;

    -- Actual tests
    test_process : process
        variable pc : unsigned(31 downto 0) := (others => '0');
    begin
        report "Starting Decode test bench";
        f_reset <= '1';
        wait for clock_period;
        f_reset <= '0';

        -- Test case 1: I-type instruction
        report "Test 1a: I-type instruction (addi $10, $0, 4) SHOULD EXECUTE";
        f_instruction <= "001000" & "00000" & "01010" & "0000000000000100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        wait for clock_period;

        report "Test 1b: I-type instruction (addi $1, $0, 1) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "001000" & "00000" & "00001" & "0000000000000001";
        f_pcplus4 <= std_logic_vector(pc + 4);
        wait for clock_period;

        -- report "Stall for Test 1 to complete (addi $0, $0, 0)";
        -- pc := pc + 4;
        -- f_instruction <= "00100000000000000000000000000000";
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- wait for clock_period;

        -- report "Write back test 1a (addi $0, $0, 0)";
        -- pc := pc + 4;
        -- f_instruction <= "00100000000000000000000000000000";
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(4, 32));
        -- wait for clock_period;

        -- Test case 2: R-type instruction
        report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD FORWARD";
        pc := pc + 4;
        f_instruction <= "000000" & "00001" & "01010" & "00010" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        wait for clock_period;

        -- report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD STALL";
        -- pc := pc + 4;
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(4, 32));
        -- wait for clock_period;

        -- report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD EXECUTE";
        -- pc := pc + 4;
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(1, 32));
        -- wait for clock_period;

        report "Test 2b: R-type instruction without writeback (sub $3, $10, $1) SHOULD FORWARD";
        pc := pc + 4;
        f_instruction <= "000000" & "01010" & "00001" & "00011" & "00000" & "100010";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(4, 32));
        wait for clock_period;

        -- report "Stall for Test 2 to complete (addi $0, $0, $0)";
        -- pc := pc + 4;
        -- f_instruction <= "00100000000000000000000000000000";
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(0, 32));
        -- wait for clock_period;

        -- report "Stall for Test 2 to complete (addi $0, $0, $0)";
        -- pc := pc + 4;
        -- f_instruction <= "00100000000000000000000000000000";
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(5, 32));
        -- wait for clock_period;

        -- report "Stall for Test 2 to complete (addi $0, $0, $0)";
        -- pc := pc + 4;
        -- f_instruction <= "00100000000000000000000000000000";
        -- f_pcplus4 <= std_logic_vector(pc + 4);
        -- w_regdata <= std_logic_vector(to_unsigned(3, 32));
        -- wait for clock_period;

        -- Test case 3: J-type instructions
        report "Test 3a: Jump instruction (j 0x123abc) SHOULD EXECUTE";
        pc := (31 downto 29 => '1', others => '0');
        f_instruction <= "000010" & "00000100100011101010111100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(1, 32));
        wait for clock_period;

        report "Test 3b: Jump and link instruction (jal 0x456def) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "000011" & "00010001010110110111101111";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(5, 32));
        wait for clock_period;

        -- Reset pipeline
        f_reset <= '1';
        wait for clock_period;
        f_reset <= '0';

        -- Test case 4: Load instruction
        report "Test 4a: Load instruction (lw $4 0x7891)";
        pc := pc + 4;
        f_instruction <= "100011" & "00000" & "00100" & "0111100010010001";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;

        report "Test 4b: Add instruction (add $5 $4 $10) SHOULD STALL";
        pc := pc + 4;
        f_instruction <= "000000" & "00101" & "00100" & "01010" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;

        report "Test 4b: Add instruction (add $5 $4 $10) SHOULD FORWARD";
        pc := pc + 4;
        f_instruction <= "000000" & "00101" & "00100" & "01010" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;

        -- Test case 5: Shamt instruction
        report "Test 5: Logical right shift (srl $6 $1 3)";
        pc := pc + 4;
        f_instruction <= "000000" & "00000" & "00001" & "00110" & "00011" & "000010";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(8, 32));
        wait for clock_period;

        report "Stall for the rest of the test";
        pc := pc + 4;
        f_instruction <= "00100000000000000000000000000000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
	    wait;
    end process;
end;
