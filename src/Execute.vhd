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
        m_forward_data : in std_logic_vector(31 downto 0);
        
        --- OUTPUTS ---
        -- To the Memory stage
        alu_result : out std_logic_vector(31 downto 0);
        writedata : out std_logic_vector(31 downto 0);
        readwrite_flag : out std_logic_vector(1 downto 0);
        -- Branch
        branch_taken : out STD_LOGIC;
        branch_target_addr : out STD_LOGIC_VECTOR (31 downto 0)
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

        -- Keep track of if readdata is forwarded or not
        variable d1_isforwarded : std_logic;
        variable d2_isforwarded : std_logic;
        
        -- result of multiplication
        variable product : std_logic_vector(63 downto 0);
    
    begin
        
        if (now < 1 ps or f_reset = '1') then
            sig_alu <= std_logic_vector(to_unsigned(0, 32));
            sig_writedata <= std_logic_vector(to_unsigned(0, 32));
            sig_rw_flag <= "00";	-- Neither
            sig_br_flag <= '0';
            sig_br_addr <= std_logic_vector(to_unsigned(0, 32));
        
        elsif (rising_edge(clock)) then
            -- Initially assume no forwarding
            d1_isforwarded := '0';
            d2_isforwarded := '0';

            -- Forwarding (execution)
            if(e_forward_ex='1') then
                if(e_forwardop_ex="10") then
                    readdata1 := sig_alu;
                    d1_isforwarded := '1';
                elsif(e_forwardop_ex="01") then
                    readdata2 := sig_alu;
                    d2_isforwarded := '1';
                elsif(e_forwardop_ex="11") then
                    readdata1 := sig_alu;
                    d1_isforwarded := '1';
                    readdata2 := sig_alu;
                    d2_isforwarded := '1';
                end if;
            end if;
            -- Forwarding (memory)
            if(e_forward_mem='1') then
                if(e_forwardop_mem="10") then
                    readdata1 := m_forward_data;
                    d1_isforwarded := '1';
                elsif(e_forwardop_mem="10") then
                    readdata2 := m_forward_data;
                    d2_isforwarded := '1';
                elsif(e_forwardop_mem="11") then
                    readdata1 := m_forward_data;
                    d1_isforwarded := '1';
                    readdata2 := m_forward_data;
                    d2_isforwarded := '1';
                end if;
            end if;

            report to_hstring(readdata1);
            report to_hstring(readdata2);
            report std_logic'image(d1_isforwarded);
            report std_logic'image(d2_isforwarded);

            -- If readdata1 or readdata2 is not forwarded, then use decode output
            if (d1_isforwarded = '0') then
                readdata1 := e_readdata1;
            end if;
            if (d2_isforwarded = '0') then
                readdata2 := e_readdata2;
            end if;
            
            -- Get alu according type of instruction
            
            -- R-type
            -- shift: data1=shamt, data2=rt
            -- otherwise data1=rs, data2=rt
            if(e_insttype = "00") then
                -- R-type instructions never read or write
                sig_rw_flag <= "00";
                case e_opcode is
                -- Arithmetic
                    -- Add rs+rt
                    when ADD =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(readdata2));
                        sig_br_flag <= '0';
                    -- Subtract
                    When SUB =>
                        sig_alu <= std_logic_vector(signed(readdata1) - signed(readdata2));
                        sig_br_flag <= '0';
                    
                    -- directly write to HI and LO
                    -- Multiply
                    when MULT =>
                        product := std_logic_vector(signed(readdata1) * signed(readdata2));
                        HI <= product(63 downto 32);
                        LO <= product(31 downto 0);
                        sig_alu <= LO;
                        sig_br_flag <= '0';
                    -- Divide
                    When DIV =>
                        sig_alu <= std_logic_vector(signed(readdata1)/signed(readdata2));
                        HI <= std_logic_vector(signed(readdata1) mod signed(readdata2));
                        LO <= std_logic_vector(signed(readdata1)/signed(readdata2));
                        sig_br_flag <= '0';
                    -- Set less than
                    when SLT =>
                        if (readdata1<readdata2) then
                            sig_alu <= std_logic_vector(to_unsigned(1, 32));
                        else
                            sig_alu <= std_logic_vector(to_unsigned(0, 32));
                        end if;
                        sig_br_flag <= '0';
                -- Logical
                    -- And
                    when L_AND =>
                        sig_alu <= readdata1 and readdata2;
                        sig_br_flag <= '0';
                    -- Or
                    when L_OR =>
                        sig_alu <= readdata1 or readdata2;
                        sig_br_flag <= '0';
                    -- Nor
                    when L_NOR =>
                        sig_alu <= readdata1 nor readdata2;
                        sig_br_flag <= '0';
                    -- Xor
                    when L_XOR =>
                        sig_alu <= readdata1 xor readdata2;
                        sig_br_flag <= '0';
                        
                -- Transfer
                    -- Move from HI
                    when MFHI => 
                        sig_alu <= HI;
                        sig_br_flag <= '0';
                    -- Move from LO
                    when MFLO =>
                        sig_alu <= LO;
                        sig_br_flag <= '0';
                    
                -- Shift
                    -- Shift left logical
                    when S_SLL =>
                        sig_alu <= std_logic_vector(unsigned(readdata2) SLL to_integer(unsigned(readdata1)));
                        sig_br_flag <= '0';
                    -- Shift right logical
                    when S_SRL =>
                        sig_alu <= std_logic_vector(unsigned(readdata2) SRL to_integer(unsigned(readdata1)));
                        sig_br_flag <= '0';
                    -- Shift right arithmetic
                    when S_SRA =>
                        sig_alu <= to_stdlogicvector(to_bitvector(readdata2) SRA to_integer(signed(readdata1)));
                        sig_br_flag <= '0';
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
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                    -- SltI
                    when SLTI =>
                        if(readdata1 < e_imm) then 
                            sig_alu <= std_logic_vector(to_unsigned(1, 32));
                        else
                            sig_alu <= std_logic_vector(to_unsigned(0, 32));
                        end if;
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                -- Logical
                    -- AndI
                    when ANDI =>
                        sig_alu <= readdata1 and e_imm;
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                    -- OrI
                    when ORI =>
                        sig_alu <= readdata1 or e_imm;
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                    -- XorI
                    when XORI =>
                        sig_alu <= readdata1 xor e_imm;
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                -- Transfer
                    -- Load upper I
                    when LUI =>
                        sig_alu <= std_logic_vector(unsigned(e_imm) SLL 16);
                        sig_rw_flag <= "00";
                        sig_br_flag <= '0';
                
                -- Memory -- directly access mem
                    -- Load word (sign extend)
                    when LW =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(e_imm));
                        sig_rw_flag <= "01";
                        sig_br_flag <= '0';
                    -- Store word (sign extend)
                    when SW =>
                        sig_alu <= std_logic_vector(signed(readdata1) + signed(e_imm));
                        sig_rw_flag <= "10";
                        sig_writedata <= readdata2;
                        sig_br_flag <= '0';
                
                -- Control-flow
                    -- Branch on equal
                    when BEQ =>
                        if(readdata1=readdata2) then
                            sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm));
                            sig_br_flag <= '1';
                        else
                            sig_br_flag <= '0';
                        end if;
                        sig_rw_flag <= "00";
                    -- Branch on not equal
                    when BNE =>
                        if(readdata1 /= readdata2) then 
                            sig_br_addr <= std_logic_vector(signed(f_nextPC) + signed(e_imm));
                            sig_br_flag <= '1'; 
                        else
                            sig_br_flag <= '0';
                        end if;
                        sig_rw_flag <= "00";

                    when others => report "Unreachable!" severity FAILURE;
                end case;
            -- J-type
            elsif(e_insttype="10") then
                -- J-type instructions never read or write
                sig_rw_flag <= "00";
                sig_br_flag <= '1';

                case e_opcode is 
                -- Control-flow
                    -- Jump
                    when J =>
                        sig_br_addr <= readdata1;
                    -- Jump and link
                    when JAL =>
                        sig_alu <= std_logic_vector(signed(f_nextPC) + 8);
                        sig_br_addr <= readdata1;
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
