library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute_tb is
end execute_tb;

architecture behavior of execute_tb is

	-- Opcodes
	--- R-type
	constant ADD : std_logic_vector(5 downto 0) := "100000";
	constant SUB : std_logic_vector(5 downto 0) := "100010";
	constant MULT : std_logic_vector(5 downto 0) := "011000";
	constant DIV : std_logic_vector(5 downto 0) := "011010";
	constant SLT : std_logic_vector(5 downto 0) := "101010";
	constant L_AND : std_logic_vector(5 downto 0) := "100100";
	constant L_OR : std_logic_vector(5 downto 0) := "100101";
	constant L_NOR : std_logic_vector(5 downto 0) := "100111";
	constant L_XOR : std_logic_vector(5 downto 0) := "100110";
	constant MFHI : std_logic_vector(5 downto 0) := "010000";
	constant MFLO : std_logic_vector(5 downto 0) := "010010";
	constant S_SLL : std_logic_vector(5 downto 0) := "000000";
	constant S_SRL : std_logic_vector(5 downto 0) := "000010";
	constant S_SRA : std_logic_vector(5 downto 0) := "000011";
	constant JR : std_logic_vector(5 downto 0) := "001000";
	
	--- I-type
	-- Arithmetic
	constant ADDI : std_logic_vector(5 downto 0) := "001000";
	constant SLTI : std_logic_vector(5 downto 0) := "001010";
	-- Logical
	constant ANDI : std_logic_vector(5 downto 0) := "001100";
	constant ORI : std_logic_vector(5 downto 0) := "001101";
	constant XORI : std_logic_vector(5 downto 0) := "001110";
	-- Transfer
	constant LUI : std_logic_vector(5 downto 0) := "001111";
	-- Memory
	constant LW : std_logic_vector(5 downto 0) := "100011";			
	constant SW : std_logic_vector(5 downto 0) := "101011";					
	-- Control-flow
	constant BEQ : std_logic_vector(5 downto 0) := "000100";
	constant BNE : std_logic_vector(5 downto 0) := "000101";
	
	--- J-type
	-- Jump
	constant J : std_logic_vector(5 downto 0) := "000010";
	-- Jump and link
	constant JAL : std_logic_vector(5 downto 0) := "000011";
	
	component execute is
		port(
			--- INPUTS ---
		  -- From the Decode state
		  e_insttype : in std_logic_vector(1 downto 0);
		  e_readdata1 : in std_logic_vector(31 downto 0);
        e_readdata2 : in std_logic_vector(31 downto 0);
		  e_imm : in std_logic_vector(31 downto 0);
		  -- funct if R; opcode for I and J
        e_opcode : in std_logic_vector(5 downto 0);
        -- Clock
        clock : in std_logic;
        -- From the Fetch stage
        f_reset : in std_logic;
		  f_nextPC : in std_logic_vector(31 downto 0); -- PC+4
		  -- Forwarding
		  -- Signal to Execute to use the forwarded value from Execute
        e_forward_ex : in std_logic;
        -- Indicate which operand the forwarded value from Execute maps to
        -- "10" = readdata1 || "01" = readdata2 || "11" = both
        e_forwardop_ex : in std_logic_vector(1 downto 0);
        -- Signal to Execute to use the forwarded value from Memory
        e_forward_mem : in std_logic;
        -- Indicate which operand the forwarded value from Memory maps to
        -- "10" = readdata1 || "01" = readdata2 || "11" = both
        e_forwardop_mem : in std_logic_vector(1 downto 0);
		  -- Forwarded data from memory
		  e_forward_data : in std_logic_vector(31 downto 0);
        
		  --- OUTPUTS ---
        -- To the Memory stage
        alu_result : out std_logic_vector(31 downto 0);
        writedata : out std_logic_vector(31 downto 0);
		  readwrite_flag: out std_logic_vector(1 downto 0);
		  -- Branch
		  branch_taken: OUT STD_LOGIC;
		  branch_target_addr: OUT STD_LOGIC_VECTOR (31 DOWNTO 0)	
		
		);
	end component;
	
	--- Test signals ---
	-- Inputs
	signal clock : std_logic := '0';
	constant clock_period : time := 1 ns;
	signal e_insttype : std_logic_vector(1 downto 0);
	signal e_opcode : std_logic_vector(5 downto 0);
	signal e_readdata1 : std_logic_vector(31 downto 0);
	signal e_readdata2 : std_logic_vector(31 downto 0);
	signal e_imm : std_logic_vector(31 downto 0);
	signal e_forward_ex : std_logic;
	signal e_forwardop_ex : std_logic_vector (1 downto 0);
	signal e_forward_mem : std_logic;
	signal e_forwardop_mem: std_logic_vector (1 downto 0);
	signal e_forward_data : std_logic_vector(31 downto 0);
	signal f_reset : std_logic;
	signal f_nextPC : std_logic_vector(31 downto 0);
	
	-- Outputs
	signal alu_result : std_logic_vector (31 downto 0);
	signal writedata : std_logic_vector(31 downto 0);
	signal readwrite_flag : std_logic_vector(1 downto 0);
		  -- Branch
	signal branch_taken : STD_LOGIC;
	signal branch_target_addr: STD_LOGIC_VECTOR (31 DOWNTO 0);
	
	-- HI and LO
	signal HI : std_logic_vector(31 downto 0);
	signal LO : std_logic_vector(31 downto 0);
	
begin 
	exec : execute
	port map(
		-- Inputs
		clock => clock,
		e_insttype => e_insttype,
		e_opcode => e_opcode,
		e_readdata1 => e_readdata1,
		e_readdata2 => e_readdata2,
		e_imm => e_imm,
		e_forward_ex => e_forward_ex,
		e_forwardop_ex => e_forwardop_ex,
		e_forward_mem => e_forward_mem,
		e_forwardop_mem => e_forwardop_mem,
		e_forward_data => e_forward_data,
		f_reset => f_reset,
		f_nextPC => f_nextPC,
		
		-- Outputs
		alu_result => alu_result,
		writedata => writedata,
		readwrite_flag => readwrite_flag,
		branch_taken => branch_taken,
		branch_target_addr => branch_target_addr
	);
	
	
	clk_process : process
	begin
		clock <= '1';
		wait for clock_period/2;
		clock <= '0';
		wait for clock_period/2;
	end process;
	
	-- Tests
	test_process : process
	begin
		report "Execute test";
		f_reset <= '1';
		wait for clock_period;
		f_reset <= '0';
		
		-- Without forwarding
		e_forward_ex <= '0';
		e_forward_mem <= '0';
		
		-- R-type 
		e_insttype <= "00";
			--shift: data1=shamt, data2=rt
			-- otherwise data1=rs, data2=rt
		report "============R-type instructions==========";
		--- Arithmetic
		report "---------------Arithmetic----------------";
		-- Add
		report "Add: ";
		e_opcode <= ADD;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(2, 32))) report "Expected result 2" severity error;
		 
		-- Subtract
		report "Subtract: ";
		e_opcode <= SUB;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected result 0" severity error;
		
		-- Multiply
		report "Multiply: ";
		e_opcode <= MULT;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- Divide
		report "Divide: ";
		e_opcode <= DIV;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- Set less than
		report "Set less than: ";
		e_opcode <= SLT;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected 0 (not smaller than)" severity error;
		
		
		--- Logical
		report "---------------Logical----------------";
		-- And
		report "And: ";
		e_opcode <= L_AND;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- Or
		report "Or: ";
		e_opcode <= L_OR;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(2, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected result 0" severity error;
		
		-- Nor
		report "Nor: ";
		e_opcode <= L_NOR;
		e_readdata1 <= std_logic_vector(to_unsigned(0, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- Xor
		report "Xor: ";
		e_opcode <= L_XOR;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		
		--- Transfer
		report "---------------Transfer----------------";
		-- Move from HI
		report "Move from HI: ";
		e_opcode <= MFHI;
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected result 0" severity error;
		
		-- Move from LO
		report "Move from LO: ";
		e_opcode <= MFLO;
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 0" severity error;
		
		--- Shift
		report "---------------Shift----------------";
		-- Shift left logical
		report "Shift left logical: ";
		e_opcode <= S_SLL;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(2, 32))) report "Expected result 2" severity error;
		
		-- Shift right logical
		report "Shift right logical: ";
		e_opcode <= S_SRL;
		e_readdata1 <= std_logic_vector(to_unsigned(2, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- Shift right arithmetic
		report "Shift right arithmetic: ";
		e_opcode <= S_SRA;
		e_readdata1 <= std_logic_vector(to_unsigned(2, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		--- Control-flow
		report "---------------Control-flow----------------";
		-- Jump register
		report "Jump register: ";
		e_opcode <= JR;
		e_readdata1 <= std_logic_vector(to_unsigned(2, 32));
		wait for clock_period;
		assert (branch_target_addr = std_logic_vector(to_unsigned(2, 32))) report "Branch addr == 2" severity error;
		assert (branch_taken = '1') report "Branch should be taken";
		
		-- I-type rs=readdata1 rt=readdata2
		report "===========I-type instructions==========";
		--- Arithmetic
		report "---------------Arithmetic----------------";
		-- AddI
		report "ADDI: ";
		e_opcode <= ADDI;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(2, 32))) report "Expected result 2" severity error;
		
		-- SltI
		--- Logical
		report "---------------Logical----------------";
		report "Set less than immediate: ";
		e_opcode <= SLT;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected 0 (not smaller than)" severity error;
		
		-- AndI
		report "AndI: ";
		e_opcode <= ANDI;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(1, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		-- OrI
		report "OrI: ";
		e_opcode <= ORI;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(2, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(0, 32))) report "Expected result 0" severity error;
		
		-- XorI
		report "XorI: ";
		e_opcode <= XORI;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		
		--- Transfer
		report "---------------Transfer----------------";
		-- Load upper I
		report "Load upper I: ";
		e_opcode <= LUI;
		e_imm <= "00000000000000000000000000000001";
		wait for clock_period;
		assert (alu_result = "00000000000000001000000000000000") report "Shift left by 16 bits" severity error;
		
		--- Memory
		report "---------------Memory----------------";
		-- Load word
		report "Load word";
		e_opcode <= LW;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		assert (readwrite_flag = "01") report "ReadWrite flag set to read" severity error;
		
		-- Store word (sign extend)
		report "Store word";
		e_opcode <= SW;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (alu_result = std_logic_vector(to_unsigned(1, 32))) report "Expected result 1" severity error;
		assert (readwrite_flag = "10") report "ReadWrite flag set to write" severity error;
		
		--- Control-flow
		report "---------------Control-flow----------------";
		-- Branch on equal
		report "Branch on equal";
		e_opcode <= BEQ;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(1, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		f_nextPC <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (branch_target_addr = std_logic_vector(to_unsigned(5, 32))) report "Expected result 5" severity error;
		assert (branch_taken = '1') report "Branch should be taken";
		
		-- Branch on not equal
		report "Branch on not equal";
		e_opcode <= BNE;
		e_readdata1 <= std_logic_vector(to_unsigned(1, 32));
		e_readdata2 <= std_logic_vector(to_unsigned(0, 32));
		e_imm <= std_logic_vector(to_unsigned(0, 32));
		f_nextPC <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (branch_target_addr = std_logic_vector(to_unsigned(5, 32))) report "Expected result 5" severity error;
		assert (branch_taken = '1') report "Branch should be taken";
		
		-- J-type
		report "===========J-type instructions==========";
		--- Control-flow
		report "---------------Control-flow----------------";
		-- Jump
		report "Jump";
		e_opcode <= J;
		e_readdata1 <= std_logic_vector(to_unsigned(4, 32));
		wait for clock_period;
		assert (branch_target_addr = std_logic_vector(to_unsigned(4, 32))) report "Expected result 4" severity error;
		assert (branch_taken = '1') report "Branch should be taken";
		
		-- Jump and link
		report "Jump and link";
		e_opcode <= JAL;
		e_readdata1 <= std_logic_vector(to_unsigned(4, 32));
		f_nextPC <= std_logic_vector(to_unsigned(0, 32));
		wait for clock_period;
		assert (branch_target_addr = std_logic_vector(to_unsigned(4, 32))) report "Expected result 4" severity error;
		assert (branch_taken = '1') report "Branch should be taken";
		assert (alu_result = std_logic_vector(to_unsigned(8, 32))) report "Expected result 8" severity error;
	
	report "End of testing";
	end process;

end;
	
	