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
            -- Signal to execute or memory stage to forward a value
            e_forward : out std_logic
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
        e_forward => e_forward
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

        -- Test case 1: I-type instruction, no hazard or forwarding
        report "Test 1a: I-type instruction (addi $10, $0, 4) SHOULD EXECUTE";
        f_instruction <= "00100000000010100000000000000100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        wait for clock_period;

        report "Test 1b: I-type instruction (addi $1, $0, 1) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "00100000000000010000000000000001";
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

        -- Test case 2: R-type instruction, no hazard or forwarding, testing
        -- writeback capabilities
        report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD STALL";
        pc := pc + 4;
        f_instruction <= "00000000001010100001000000100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        wait for clock_period;

        report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD STALL";
        pc := pc + 4;
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(4, 32));
        wait for clock_period;

        report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD EXECUTE";
        pc := pc + 4;
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(1, 32));
        wait for clock_period;

        report "Test 2b: R-type instruction without writeback (sub $3, $10, $1) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "00000001010000010001100000100010";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
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
        f_instruction <= "00001000000100100011101010111100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;

        report "Test 3b: Jump and link instruction (jal 0x456def) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "00001100010001010110110111101111";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;

        report "Stall for the rest of the test";
        pc := pc + 4;
        f_instruction <= "00100000000000000000000000000000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        wait for clock_period;
	wait;
    end process;
end;
