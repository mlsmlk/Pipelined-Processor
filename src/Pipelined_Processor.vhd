library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pipelined_processor is
    port(
        --- INPUTS ---
        -- Clock --
        clock : in std_logic;
        reset : in std_logic
    );
end pipelined_processor;

architecture arch of pipelined_processor is
    ----------------------------
    -- COMPONENT DECLARATIONS --
    ----------------------------

    --- INSTRUCTION MEMORY ---
    -- ***TODO***

    --- INSTRUCTION FETCH ---
    -- ***TODO***

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
    -- ***TODO***

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

begin

    ------------------------------------
    -- CONNECTING COMPONENTS TOGETHER --
    ------------------------------------

    --- INSTRUCTION MEMORY ---
    -- ***TODO***

    --- INSTRUCTION FETCH ---
    -- ***TODO***

    --- DECODE ---
    dec : decode
    port map(
        -- Inputs
        clock,
        write_reg_file => ???,
        f_instruction => ???,
        f_reset => ???,
        f_pcplus4 => ???,
        w_regdata => write_data,
        -- Outputs
        f_stall => ???,
        e_insttype => ???,
        e_opcode => ???,
        e_readdata1 => ???,
        e_readdata2 => ???,
        e_imm => ???,
        e_forward_ex => ???,
        e_forwardop_ex => ???,
        e_forward_mem => ???,
        e_forwardop_mem => ???
    );

    --- EXECUTE ---
    -- ***TODO***

    --- MEMORY ---
    mem : data_memory
    port map(
        -- Inputs
        clock,
        alu_in => ???,
        mem_in => ???,
        readwrite_flag => ???,
        write_file_flag => ???,
        -- Outputs
        mem_res,
        mem_flag,
        alu_res
    );

    --- WRITEBACK ---
    wb : write_back
    port map(
        -- Inputs
        clk => clock,
        mem_res,
        alu_res,
        mem_flag,
        -- Outputs
        write_data => w_regdata
    );
end;
