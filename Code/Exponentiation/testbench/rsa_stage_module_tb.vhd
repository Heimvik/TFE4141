library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;


entity rsa_stage_module_tb is
    generic(
        c_block_size : integer := 256;
        log2_c_block_size : integer := 8;
        c_pipeline_stages : integer := 1;
        num_status_bits : integer := 32;
        CLK_PERIOD : time := 1 ns;
        
        e_int : integer := 8954;
        n_int : integer := 25553;
        m_int : integer := 641
    );
end rsa_stage_module_tb;

architecture rtl of rsa_stage_module_tb is    
    signal clk : std_logic;
    signal rst : std_logic;
    
    --Control signals             
    signal ili : std_logic;
    signal ipi : std_logic;
    signal ipo : std_logic;
    signal ilo : std_logic;
    
    --Data signals
    signal dpo : std_logic_vector (c_block_size-1 downto 0);
    signal dco : std_logic_vector (c_block_size-1 downto 0);
    signal dpi : std_logic_vector (c_block_size-1 downto 0);
    signal dci : std_logic_vector (c_block_size-1 downto 0);
    
    --Status registers
    signal rsm_status : std_logic_vector(num_status_bits-1 downto 0);
    signal bm_status : std_logic_vector(num_status_bits-1 downto 0);
    
    --Init values
    signal n : std_logic_vector (c_block_size-1 downto 0) := std_logic_vector(to_unsigned(n_int,c_block_size));
    signal es : std_logic_vector ((c_block_size/c_pipeline_stages)-1 downto 0) := std_logic_vector(to_unsigned(e_int,c_block_size));
    
    --Test values
    signal m_in : std_logic_vector (c_block_size-1 downto 0) := std_logic_vector(to_unsigned(m_int,c_block_size));
    signal c_out : std_logic_vector (c_block_size-1 downto 0);

begin

    DUT : entity work.rsa_stage_module
        generic map(
            c_block_size => c_block_size,
            log2_c_block_size => log2_c_block_size,
            c_pipeline_stages => c_pipeline_stages,
            num_status_bits => num_status_bits
        )
        port map(
            CLK => clk,
            RST => rst,
            
            --Input control signals to the blakeley stage module are outputs from the tb
            ILI => ilo,
            IPI => ipo,
            
            --Output control signals from the blakeley stage module are inputs to the tb
            IPO => ipi,
            ILO => ili,
            
            N => n,
            ES => es,
            
            DPI => dpo,
            DCI => dco,
            DPO => dpi,
            DCO => dci,
            
            rsm_status => rsm_status
            --bm_status => bm_status
        );

    clk_gen : process is
    begin
        while true loop
            clk <= '1';
            wait for CLK_PERIOD/2; 
            clk <= '0';
            wait for CLK_PERIOD/2;
        end loop;
    end process clk_gen;
    
    stimuli : process is
    begin
        wait for CLK_PERIOD;
        ipo <= '0';
        ilo <= '0';
        
        --Transmit inputs
        dco <= std_logic_vector(to_unsigned(1,c_block_size));
        dpo <= m_in;
        
        --Signal inputs transmitted procedure
        ilo <= '1';
        wait until ipi = '1' and rising_edge(clk);
        ilo <= '0';
        
        --Wait for output ready signal
        wait until ili = '1' and rising_edge(clk);
        
        --Receive outputs
        c_out <= dci;
        
        --Signal outputs received procedure
        ipo <= '1';
        wait until ili = '0' and rising_edge(clk);
        ipo <= '0';
        
        wait;
    end process stimuli;
end rtl;
        
    
    

        
        