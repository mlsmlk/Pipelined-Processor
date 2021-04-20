library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity execute is
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
end execute;

architecture arch of execute is
    
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
        
    ----- SIGNALS -----
    -- HI and LO register to store the result of MULT and DIV
    -- MFHI, MFLO read from them
    signal HI : std_logic_vector(31 downto 0);
    signal LO : std_logic_vector(31 downto 0);
    
    -- Output signals
    signal sig_alu : std_logic_vector(31 downto 0);
    signal sig_writedata : std_logic_vector(31 downto 0);
    signal sig_rw_flag : std_logic_vector(1 downto 0);
    
    signal sig_br_flag : std_logic;
    signal sig_br_addr : std_logic_vector(31 downto 0);
    
begin
    execute_proc: process (clock, f_reset)
        ----- VARIABLES -----
        
        -- input
        variable readdata1 : std_logic_vector(31 downto 0);
        variable readdata2 : std_logic_vector(31 downto 0);
        
        -- result of multiplication
        variable product : std_logic_vector(63 downto 0);
    
    begin
        
        if (now < 1 ps) then
            sig_alu <= std_logic_vector(to_unsigned(0, 32));
            sig_writedata <= std_logic_vector(to_unsigned(0, 32));
            sig_rw_flag <= "00";	-- Neither
            sig_br_flag <= '0';
            sig_br_addr <= std_logic_vector(to_unsigned(0, 32));
        
        elsif (rising_edge(clock)) then
            -- Forwarding (execution)
            if(e_forward_ex='1') then
                if(e_forwardop_ex="10") then readdata1 := sig_alu;
                elsif(e_forwardop_ex="01") then readdata2 := sig_alu;
                elsif(e_forwardop_ex="11") then
                    readdata1 := sig_alu;
                    readdata2 := sig_alu;
                end if;
            end if;
            -- Forwarding (memory)
            if(e_forward_mem='1') then
                if(e_forwardop_mem="10") then readdata1 := e_forward_data;
                elsif(e_forwardop_mem="10") then readdata2 := e_forward_data;
                elsif(e_forwardop_mem="11") then
                    readdata1 := e_forward_data;
                    readdata2 := e_forward_data;
                end if;
            end if;
            
            -- Get alu according type of instruction
            
            -- R-type
            -- shift: data1=shamt, data2=rt
            -- otherwise data1=rs, data2=rt
            if(e_insttype = "00") then
                case e_opcode is
                -- Arithmetic
                    -- Add rs+rt
                    when ADD =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(readdata2));
                    -- Subtract
                    When SUB =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(readdata2));
                    
                    -- directly write to HI and LO
                    -- Multiply
                    when MULT =>
                        product := std_logic_vector(signed(readdata1) * signed(readdata2));
                        HI <= product(63 downto 32);
                        LO <= product(31 downto 0);
                        sig_alu <= LO;	-- TODO: pass low to alu?
                    -- Divide
                    When DIV =>
                        sig_alu <= std_logic_vector(signed(readdata1)/signed(readdata2));
                        HI <= std_logic_vector(signed(readdata1) mod signed(readdata2));
                        LO <= std_logic_vector(signed(readdata1)/signed(readdata2));
                    -- Set less than
                    when SLT =>
                        if (readdata1<readdata2) then sig_alu <= std_logic_vector(to_unsigned(1, 32));
                        else sig_alu <= std_logic_vector(to_unsigned(0, 32));
                        end if;
                -- Logical
                    -- And
                    when L_AND =>
                        sig_alu <= readdata1 and readdata2;
                    -- Or
                    when L_OR =>
                        sig_alu <= readdata1 or readdata2;
                    -- Nor
                    when L_NOR =>
                        sig_alu <= readdata1 nor readdata2;
                    -- Xor
                    when L_XOR =>
                        sig_alu <= readdata1 xor readdata2;
                        
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
                        sig_alu <= std_logic_vector(unsigned(readdata2) SLL to_integer(unsigned(readdata1)));
                    -- Shift right logical
                    when S_SRL =>
                        sig_alu <= std_logic_vector(unsigned(readdata2) SRL to_integer(unsigned(readdata1)));
                    -- Shift right arithmetic
                    when S_SRA =>
                        sig_alu <= to_stdlogicvector(to_bitvector(readdata2) SRA to_integer(signed(readdata1)));
                -- Control-flow
                    -- Jump register	-- branch_ddr = rs
                    when JR =>
                        sig_br_addr <= readdata1;
                        sig_br_flag <= '1';
                    when others => report "Unreachable!" severity FAILURE;
                    end case;
            
            -- I-type rs=readdata1 rt=readdata2
            elsif(e_insttype="01") then
                case e_opcode is 
                -- Arithmetic
                    -- AddI
                    when ADDI =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(e_imm));
                    -- SltI
                    when SLTI =>
                        if(readdata1 < e_imm) then 
                            sig_alu <= std_logic_vector(to_unsigned(1, 32));
                        else sig_alu <= std_logic_vector(to_unsigned(0, 32));
                        end if;		
                -- Logical
                    -- AndI
                    when ANDI =>
                        sig_alu <= readdata1 and e_imm;
                    -- OrI
                    when ORI =>
                        sig_alu <= readdata1 or e_imm;
                    -- XorI
                    when XORI =>
                        sig_alu <= readdata1 xor e_imm;
                -- Transfer
                    -- Load upper I
                    when LUI =>
                        sig_alu <= std_logic_vector(unsigned(e_imm) SLL 16);
                
                -- Memory -- directly access mem
                    -- Load word (sign extend)
                    when LW =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(e_imm));
                        sig_rw_flag <= "01";
                    -- Store word (sign extend)
                    when SW =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(e_imm));
                        sig_rw_flag <= "10";
                        sig_writedata <= readdata2;
                
                -- Control-flow
                    -- Branch on equal
                    when BEQ =>
                        if(readdata1=readdata2) then
                            sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm) + 4);
                            sig_br_flag <= '1';
                        end if;
                    -- Branch on not equal
                    when BNE =>
                        if(readdata1 /= readdata2) then 
                            sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm) + 4);
                            sig_br_flag <= '1'; 
                        end if;
                    when others => report "Unreachable!" severity FAILURE;
                    end case;
            -- J-type
            elsif(e_insttype="10") then
                case e_opcode is 
                -- Control-flow
                    -- Jump
                    when J =>
                        sig_br_addr <= readdata1;
                        sig_br_flag <= '1'; 
                    -- Jump and link
                    when JAL =>
                        sig_alu <= std_logic_vector(signed(f_nextPC) + 8);
                        sig_br_addr <= readdata1;
                        sig_br_flag <= '1';
                    when others => report "Unreachable!" severity FAILURE;
                    end case;
            end if;
        end if;

    end process;
    
    alu_result <= sig_alu;
   writedata <= sig_writedata;
    readwrite_flag <= sig_rw_flag;
    branch_taken <= sig_br_flag;
    branch_target_addr <= sig_br_addr;	
    
end arch;
