library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_processor is
    port(
        --- INPUTS ---
        -- Clock
        clock : in std_logic;
        -- Reset the processor (PC starts at 0)
        reset : in std_logic;
        -- Tell the processor to print out the memory and register values
        write_to_file : in std_logic
    );
end pipelined_processor;

architecture arch of pipelined_processor is
    ----------------------------
    -- COMPONENT DECLARATIONS --
    ----------------------------

    --- INSTRUCTION FETCH ---
    component fetch is
        port(
            --- INPUTS ---
            -- Clock
            clock : in std_logic;
            reset : in std_logic;
            -- From Execute stage
            jump_address : in std_logic_vector(31 downto 0);
            jump_flag : in std_logic;
            stall_pipeline : in std_logic;

            --- OUTPUTS ---
            -- To Decode stage
            instruction : out std_logic_vector(31 downto 0);
            program_counter_out : out std_logic_vector(31 downto 0);
            reset_out : out std_logic
        );
    end component;

    --- DECODE ---
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

    --- EXECUTE ---
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
    end component;

    --- MEMORY ---
    component data_memory is
        port(
            --- INPUTS ---
            clock : in std_logic;

            -- from execute stage
            alu_in : in std_logic_vector (31 downto 0); -- result of alu (address part in diagram)
            mem_in : in std_logic_vector (31 downto 0); -- read data 2 from execute stage (write data part in diagram)
            readwrite_flag : in std_logic_vector (1 downto 0); --flag to determine if the op code is related to memory ("01" = read, "10" = write, "00" = neither)
            write_file_flag : in std_logic := '0'; --flag to indicate the commands are finished and the memory can be written into file

            --- OUTPUTS ---
            --to write back stage
            mem_res : out std_logic_vector (31 downto 0); -- read data from mem stage
            mem_flag : out std_logic; -- mux flag (1- read mem, 0-read alu result)
            alu_res : out std_logic_vector (31 downto 0) -- result of alu
        );
    end component;

    --- WRITEBACK ---
    component write_back is
        port(
            --- INPUTS ---
            clk : in std_logic; -- clock
            mem_res : in std_logic_vector (31 downto 0); 	-- read data from mem stage
            alu_res : in std_logic_vector (31 downto 0); 	-- alu result from ex stage
            mem_flag : in std_logic; 			-- MUX flag (1- read mem, 0-read ALU result)

            --- OUTPUTS ---
            write_data : out std_logic_vector(31 downto 0) 	-- data to write back to send Decode stage
        );
    end component;


    -------------------------
    -- SIGNAL DECLARATIONS --
    -------------------------
    signal r_branch_target_addr : std_logic_vector(31 downto 0);
    signal r_branch_taken : std_logic;
    signal r_f_stall : std_logic;
    signal r_f_instruction : std_logic_vector(31 downto 0);
    signal r_f_pcplus4 : std_logic_vector(31 downto 0);
    signal r_f_reset : std_logic;
    signal r_write_data : std_logic_vector(31 downto 0);
    signal r_mem_res : std_logic_vector(31 downto 0);
    signal r_alu_in : std_logic_vector(31 downto 0);
    signal r_mem_in : std_logic_vector(31 downto 0);
    signal r_e_insttype : std_logic_vector (1 downto 0);
    signal r_e_opcode : std_logic_vector(5 downto 0);
    signal r_e_readdata1 : std_logic_vector(31 downto 0);
    signal r_e_readdata2 : std_logic_vector(31 downto 0);
    signal r_e_imm : std_logic_vector(31 downto 0);
    signal r_e_forward_ex : std_logic;
    signal r_e_forwardop_ex : std_logic_vector(1 downto 0);
    signal r_e_forward_mem : std_logic;
    signal r_e_forwardop_mem : std_logic_vector(1 downto 0);
    signal r_readwrite_flag : std_logic_vector(1 downto 0);
    signal r_mem_flag : std_logic;
    signal r_alu_res : std_logic_vector(31 downto 0);

begin

    ------------------------------------
    -- CONNECTING COMPONENTS TOGETHER --
    ------------------------------------

    --- INSTRUCTION FETCH ---
    instf : fetch
    port map(
        -- Inputs
        clock => clock,
        reset => reset,
        jump_address => r_branch_target_addr,
        jump_flag => r_branch_taken,
        stall_pipeline => r_f_stall,
        -- Outputs
        instruction => r_f_instruction,
        program_counter_out => r_f_pcplus4,
        reset_out => r_f_reset
    );

    --- DECODE ---
    dec : decode
    port map(
        -- Inputs
        clock => clock,
        write_reg_file => write_to_file,
        f_instruction => r_f_instruction,
        f_reset => r_f_reset,
        f_pcplus4 => r_f_pcplus4,
        w_regdata => r_write_data,
        -- Outputs
        f_stall => r_f_stall,
        e_insttype => r_e_insttype,
        e_opcode => r_e_opcode,
        e_readdata1 => r_e_readdata1,
        e_readdata2 => r_e_readdata2,
        e_imm => r_e_imm,
        e_forward_ex => r_e_forward_ex,
        e_forwardop_ex => r_e_forwardop_ex,
        e_forward_mem => r_e_forward_mem,
        e_forwardop_mem => r_e_forwardop_mem
    );

    --- EXECUTE ---
    ex : execute
    port map(
        -- Inputs
        clock,
        e_insttype,
        e_readdata1 => r_e_readdata1,
        e_readdata2 => r_e_readdata2,
        e_imm => r_e_imm,
        e_opcode => r_e_opcode,
        f_reset => r_f_reset,
        f_nextPC => r_f_pcplus4,
        e_forward_ex => r_e_forward_ex,
        e_forwardop_ex => r_e_forwardop_ex,
        e_forward_mem => r_e_forward_mem,
        e_forwardop_mem => r_e_forwardop_mem,
        m_forward_data => r_mem_res,
        -- Outputs
        alu_result => r_alu_in,
        writedata => r_mem_in,
        readwrite_flag => r_readwrite_flag,
        branch_taken => r_branch_taken,
        branch_target_addr => r_branch_target_addr
    );

    --- MEMORY ---
    mem : data_memory
    port map(
        -- Inputs
        clock,
        alu_in => r_alu_in,
        mem_in => r_mem_in,
        readwrite_flag => r_readwrite_flag,
        write_file_flag => write_to_file,
        -- Outputs
        mem_res => r_mem_res,
        mem_flag => r_mem_flag,
        alu_res => r_alu_res
    );

    --- WRITEBACK ---
    wb : write_back
    port map(
        -- Inputs
        clk => clock,
        mem_res => r_mem_res,
        alu_res => r_alu_res,
        mem_flag => r_mem_flag,
        -- Outputs
        write_data => r_write_data
    );
end;
