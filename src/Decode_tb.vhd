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

            -- Flag for writing the register file to a text file
            write_reg_file : in std_logic;

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
    
    ---- TEST SIGNALS ----
    -- Inputs
    signal clock : std_logic := '0';
    constant clock_period : time := 1 ns;
    signal write_reg_file : std_logic := '0';
    signal f_instruction : std_logic_vector(31 downto 0);
    signal f_reset : std_logic;
    signal f_pcplus4 : std_logic_vector(31 downto 0);
    signal w_regdata : std_logic_vector(31 downto 0);
    -- Outputs
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
        write_reg_file => write_reg_file,
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

        ---------------------------------
        -- HAZARD AND FORWARDING TESTS --
        ---------------------------------

        report "Starting Decode test bench";
        f_reset <= '1';
        wait for clock_period;
        f_reset <= '0';

        -- Test case 1: I-type instruction
        report "Test 1a: I-type instruction (addi $10, $0, 4) SHOULD EXECUTE";
        f_instruction <= "001000" & "00000" & "01010" & "0000000000000100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "001000") report "Opcode was not 001000" severity error;
        assert (e_readdata1 = std_logic_vector(to_unsigned(0, 32))) report "Readdata1 was not 0" severity error;
        assert (e_imm = std_logic_vector(to_unsigned(4, 32))) report "Immediate was not 4" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        report "Test 1b: I-type instruction (addi $1, $0, 1) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "001000" & "00000" & "00001" & "0000000000000001";
        f_pcplus4 <= std_logic_vector(pc + 4);
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "001000") report "Opcode was not 001000" severity error;
        assert (e_readdata1 = std_logic_vector(to_unsigned(0, 32))) report "Readdata1 was not 0" severity error;
        assert (e_imm = std_logic_vector(to_unsigned(1, 32))) report "Immediate was not 1" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        -- Test case 2: R-type instruction
        report "Test 2a: R-type instruction with writeback (add $2, $1, $10) SHOULD FORWARD";
        pc := pc + 4;
        f_instruction <= "000000" & "00001" & "01010" & "00010" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        --
        wait for clock_period;
        --
        assert (e_insttype = "00") report "Expected R-type instruction" severity error;
        assert (e_opcode = "100000") report "Opcode was not 100000" severity error;
        assert (e_forward_ex = '1') report "Execute forwarding was disabled when it should not have enabled" severity error;
        assert (e_forwardop_ex = "10") report "Execute forwarding operand should be 10" severity error;
        assert (e_forward_mem = '1') report "Memory forwarding was disabled when it should not have enabled" severity error;
        assert (e_forwardop_mem = "01") report "Memory forwarding operand should be 01" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        report "Test 2b: R-type instruction without writeback (add $3, $1, $1) SHOULD FORWARD";
        pc := pc + 4;
        f_instruction <= "000000" & "00001" & "00001" & "00011" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(4, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "00") report "Expected R-type instruction" severity error;
        assert (e_opcode = "100000") report "Opcode was not 100000" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '1') report "Memory forwarding was disabled when it should not have enabled" severity error;
        assert (e_forwardop_mem = "11") report "Memory forwarding operand should be 11" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        -- Test case 3: J-type instructions
        report "Test 3a: Jump instruction (j 0x123abc) SHOULD EXECUTE";
        pc := (31 downto 29 => '1', others => '0');
        f_instruction <= "000010" & "00000100100011101010111100";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(1, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "10") report "Expected J-type instruction" severity error;
        assert (e_opcode = "000010") report "Opcode was not 000010" severity error;
        assert (e_readdata1 = "11100000010010001110101011110000") report "Readdata1 was not 11100000010010001110101011110000" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        report "Test 3b: Jump and link instruction (jal 0x456def) SHOULD EXECUTE";
        pc := pc + 4;
        f_instruction <= "000011" & "00010001010110110111101111";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(5, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "10") report "Expected J-type instruction" severity error;
        assert (e_opcode = "000011") report "Opcode was not 000011" severity error;
        assert (e_readdata1 = "11100001000101011011011110111100") report "Readdata1 was not 11100000010010001110101011110000" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        -- Reset pipeline
        f_reset <= '1';
        wait for clock_period;
        f_reset <= '0';

        -- Test case 4: Load instruction
        report "Test 4a: Load instruction (lw $4 0x8791)";
        pc := pc + 4;
        f_instruction <= "100011" & "00000" & "00100" & "1000011110010001";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "100011") report "Opcode was not 100011" severity error;
        assert (e_readdata1 = std_logic_vector(to_unsigned(0, 32))) report "Readdata1 was not 0" severity error;
        assert (e_imm = "11111111111111111000011110010001") report "Immediate was not 1000011110010001 sign-extended" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        report "Test 4b: Add instruction (add $5 $4 $1) SHOULD STALL";
        pc := pc + 4;
        f_instruction <= "000000" & "00100" & "00001" & "00101" & "00000" & "100000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "001000") report "Opcode was not 001000" severity error;
        assert (e_readdata1 = std_logic_vector(to_unsigned(0, 32))) report "Readdata1 was not 0" severity error;
        assert (e_imm = std_logic_vector(to_unsigned(0, 32))) report "Immediate was not 0" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '1') report "Stall signal was low when there should have been a stall" severity error;

        report "Test 4b: Logical right shift (srl $6 $10 1) SHOULD EXECUTE PREVIOUS INSTRUCTION";
        pc := pc + 4;
        f_instruction <= "000000" & "00000" & "01010" & "00110" & "00001" & "000010";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "00") report "Expected R-type instruction" severity error;
        assert (e_opcode = "100000") report "Opcode was not 100000" severity error;
        assert (e_readdata2 = std_logic_vector(to_unsigned(1, 32))) report "Readdata2 was not 1" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '1') report "Memory forwarding was disabled when it should not have enabled" severity error;
        assert (e_forwardop_mem = "10") report "Memory forwarding operand should be 10" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        -- Test case 5: Shamt instruction
        report "Test 5: Logical right shift (srl $6 $10 1)";
        pc := pc + 4;
        f_instruction <= "000000" & "00000" & "01010" & "00110" & "00001" & "000010";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(8, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "00") report "Expected R-type instruction" severity error;
        assert (e_opcode = "000010") report "Opcode was not 000010" severity error;
        assert (e_readdata1 = std_logic_vector(to_unsigned(1, 32))) report "Readdata1 was not 1" severity error;
        assert (e_readdata2 = std_logic_vector(to_unsigned(4, 32))) report "Readdata2 was not 4" severity error;
        assert (e_forward_ex = '0') report "Execute forwarding was enabled when it should not have disabled" severity error;
        assert (e_forward_mem = '0') report "Memory forwarding was enabled when it should not have disabled" severity error;
        assert (f_stall = '0') report "Stall signal was high when there was no stall" severity error;

        -- Reset pipeline
        f_reset <= '1';
        wait for clock_period;
        f_reset <= '0';

        --------------------------------------
        -- ADDITIONAL IMMEDIATE VALUE TESTS --
        --------------------------------------

        -- Test case 6: Branch address instruction
        report "Test 6: Branch on equal (beq $0 $0 0x9123)";
        pc := pc + 4;
        f_instruction <= "000100" & "00000" & "00000" & "1001000100100011";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "000100") report "Opcode was not 000100" severity error;
        assert (e_imm = "11111111111111100100010010001100") report "Immediate was not properly address-extended" severity error;

        -- Test case 7: Unsigned extended value instruction
        report "Test 7: Load upper immediate (lui $1 0x9123)";
        pc := pc + 4;
        f_instruction <= "001111" & "00000" & "00000" & "1001000100100011";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
        --
        wait for clock_period;
        --
        assert (e_insttype = "01") report "Expected I-type instruction" severity error;
        assert (e_opcode = "001111") report "Opcode was not 001111" severity error;
        assert (e_imm = "00000000000000001001000100100011") report "Immediate was not zero-extended" severity error;

        -------------------------------------
        -- TEST PRINTING THE REGISTER FILE --
        -------------------------------------
        report "Test 8: Print register file";
        write_reg_file <= '1';
        --
        wait for clock_period;
        --
        write_reg_file <= '0';

        --- END OF UNIT TESTS ---

        report "Stall for the rest of the test";
        pc := pc + 4;
        f_instruction <= "00100000000000000000000000000000";
        f_pcplus4 <= std_logic_vector(pc + 4);
        w_regdata <= std_logic_vector(to_unsigned(0, 32));
	    wait;
    end process;
end;
