library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute is
	GENERIC(
		ram_size : INTEGER := 32768;
		mem_delay : time := 10 ns;
		clock_period : time := 1 ns
	);
    port(
        --- INPUTS ---
		  -- From the Decode state
		  e_insttype : in std_logic_vector(1 downto 0);
		  e_readdata1 : in std_logic_vector(31 downto 0);
        e_readdata2 : in std_logic_vector(31 downto 0);
		  e_imm : in std_logic_vector(31 downto 0);
		  -- funct if R; opcode for I and J
        e_opcode : in std_logic_vector(5 downto 0);
        e_forward : in std_logic; -- Also to be forwarded to the memory stage
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
        
        --- OUTPUTS ---
        -- To the Memory stage
        alu_result : out std_logic_vector(31 downto 0);
        readdata2 : out std_logic_vector(31 downto 0);
		  readwrite_flag: out std_logic_vector(1 downto 0);
		  -- Branch
		  branch_taken: OUT STD_LOGIC;
		  branch_target_addr: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
		  
    );
end execute;

architecture arch of execute is

	----- TYPE DEFINITIONS -----
	type register_file is array(0 to NUM_REGISTERS - 1) of std_logic_vector(31 downto 0);
	type Opcode is std_logic_vector(5 downto 0);
	
	----- CONSTANTS -----
   constant NUM_REGISTERS : natural := 32;
	-- Opcodes
	--- R-type
	constant ADD : opcode := "100000";
	constant SUB : opcode := "100010";
	constant MULT : opcode := "011000";
	constant DIV : opcode := "011010";
	constant SLT : opcode := "101010";
	constant L_AND : opcode := "100100";
	constant L_OR : opcode := "100101";
	constant L_NOR : opcode := "100111";
	constant L_XOR : opcode := "100110";
	constant MFHI : opcode := "010000";
	constant MFLO : opcode := "010010";
	constant S_SLL : opcode := "000000";
	constant S_SRL : opcode := "000010";
	constant S_SRA : opcode := "000011";
	constant JR : opcode := "001000";
	
	--- I-type
	-- Arithmetic
	constant ADDI : opcode := "001000";
	constant SLTI : opcode := "001010";
	-- Logical
	constant ANDI : opcode := "001100";
	constant ORI : opcode := "001101";
	constant XORI : opcode := "001110";
	-- Transfer
	constant LUI : opcode := "001111";
	-- Memory
	constant LW : opcode := "100011";			
	constant SW : opcode := "101011";					
	-- Control-flow
	constant BEQ : opcode := "000100";
	constant BNE : opcode := "000101";
	
	--- J-type
	-- Jump
	constant J : opcode := "000010";
	-- Jump and link
	constant JAL : opcode := "000011";
		
	----- SIGNALS -----
   -- Register file
   signal registers: register_file; -- TODO: delete this if no need
	-- HI and LO register to store the result of MULT and DIV
	-- MFHI, MFLO read from them
	signal HI : std_logic_vector(31 downto 0);
	signal LO : std_logic_vector(31 downto 0);
	-- PC
	signal PC : std_logic_vector(31 downto 0);
	
	-- Output signals
	signal sig_alu : std_logic_vector(31 downto 0);
	signal sig_writedata : std_logic_vector(31 downto 0);
	signal sig_rw_flag : std_logic_vector(1 downto 0);
	
	signal sig_br_flag : std_logic;
	signal sig_br_addr ： std_logic_vector(31 downto 0);
	
begin
	execute_proc: process (clock, f_reset)
		----- VARIABLES -----
		variable registers_var : register_file;
		
		-- input
		variable inst_type : std_logic_vector(1 downto 0);
		
		-- result of multiplication
		variable product : std_logic_vector(63 downto 0);
	
	begin
		registers_var := registers;
		
		-- Get alu according type of instruction
		inst_type := e_insttype;
		
		-- R-type
		-- shift: data1=shamt, data2=rt
		-- otherwise data1=rs, data2=rt
		if(inst_type = "00") then
			case e_opcode is
			-- Arithmetic
				-- Add rs+rt
				when ADD =>
					sig_alu <= std_logic_vector(signed(e_readdata1) + signed(e_readdata2));
				-- Subtract
				When SUB =>
					sig_alu <= std_logic_vector(signed(e_readdata1) + signed(e_readdata2));
				
				-- directly write to HI and LO
				-- Multiply
				when MULT =>
					product <= std_logic_vector(signed(e_readdata1) * signed(e_readdata2));
					HI <= product(63 downto 32);
					LO <= product(31 downto 0);
					sig_alu <= LO	-- TODO: pass low to alu?
				-- Divide
				When DIV =>
					sig_alu <= std_logic_vector(signed(e_readdata1)/signed(e_readdata2));
					HI <= std_logic_vector(signed(e_readdata1) mod signed(e_readdata2));
					LO <= std_logic_vector(signed(e_readdata1)/signed(e_readdata2));
				-- Set less than
				when SLT =>
					if (e_readdata1<e_readdata2) then sig_alu <= std_logic_vector(resize('1', 32));
					else sig_alu <= std_logic_vector(resize('0', 32));
					
			-- Logical
				-- And
				when L_AND =>
					sig_alu <= e_readdata1 and e_readdata2;
				-- Or
				when L_OR =>
					sig_alu <= e_readdata1 or e_readdata2;
				-- Nor
				when L_NOR =>
					sig_alu <= e_readdata1 nor e_readdata2;
				-- Xor
				when L_XOR =>
					sig_alu <= e_readdata1 xor e_readdata2;
					
			-- Transfer
				-- Move from HI
				when MFHI => 
					sig_alu <= HI;
				-- Move from LO
				when MFLO =>
					sig_alu <= LO;
				
			-- Shift
				-- Shift left logical
				when S_SLL =>
					sig_alu <= e_readdata2 << e_readdata1;
				-- Shift right logical
				when S_SRL =>
					sig_alu <= e_readdata2 >> e_readdata1;
				-- Shift right arithmetic
				when S_SRA =>
					sig_alu <= e_readdata2 >>> e_readdata1;
			-- Control-flow
				-- Jump register	-- branch_ddr = rs
				when JR =>
					sig_br_addr <= e_readdata1;
					sig_br_flag <= '1';
		
		-- I-type rs=readdata1 rt=readdata2
		elsif(inst_type=="01") then
			case e_opcode is 
			-- Arithmetic
				-- AddI
				when ADDI =>
					sig_alu <= std_logic_vector(signed(e_readdata1) + signed(e_imm));
				-- SltI
				when SLTI =>
					if(e_readdata1 < e_imm) then 
						sig_alu <= std_logic_vector(resize('1', 32));
					else sig_alu <= std_logic_vector(resize('0', 32));
		
			-- Logical
				-- AndI
				when ANDI =>
					sig_alu <= e_readdata1 and e_imm;
				-- OrI
				when ORI =>
					sig_alu <= e_readdata1 or e_imm;
				-- XorI
				when XORI =>
					sig_alu <= e_readdata1 xor e_imm;
			-- Transfer
				-- Load upper I
				when LUI =>
					sig_alu <= e_imm << "010000";
			
			-- Memory -- directly access mem
				-- Load word (sign extend)
				when LW =>
					sig_alu <= std_logic_vector(signed(e_readdata1) + signed(e_imm));
					sig_rw_flag <= "01";
				-- Store word (sign extend)
				when SW =>
					sig_alu <= std_logic_vector(signed(e_readdata1) + signed(e_imm));
					sig_rw_flag <= "10";
					sig_writedata <= e_readdata2;
			
			-- Control-flow
				-- Branch on equal
				when BEQ =>
					if(e_readdata1==e_readdata2) then
						sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm) + "0100");
						sig_br_flag <= '1';
				-- Branch on not equal
				when BNE =>
					if(e_readdata1!=e_readdata2) then 
						sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm) + "0100");
						sig_br_flag <= '1'; 
		
		-- J-type
		elsif(inst_type=="10") then
			case e_opcode is 
			-- Control-flow
				-- Jump
				when J =>
					sig_br_addr <= e_readdata1;
					sig_br_flag <= '1'; 
				-- Jump and link
				when JAL =>
					sig_alu <= std_logic_vector(signed(f_nextPC) + "1000");
					sig_br_addr <= e_readdata1;
					sig_br_flag <= '1';
		
	end execute_proc;	
	
	alu_result <= sig_alu;
   readdata2 <= sig_writedata;
	readwrite_flag <= sig_rw_flag;
	branch_taken <= sig_br_flag;
	branch_target_addr <= sig_br_addr;	
	
end arch;
