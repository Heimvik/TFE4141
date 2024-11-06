library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.tb_utils.all;

entity rsa_pipeline_tb is
    generic(
        c_block_size : integer := 256;
        log2_c_block_size : integer := 8;
        
        num_pipeline_stages : integer := 16;
        log2_es_size : integer := 4;   --Has to be log2(c_block_size/num_pipeline_stages)
        
        num_status_bits : integer := 32;
        CLK_PERIOD : time := 1 ns        
    );
end rsa_pipeline_tb;

architecture rtl of rsa_pipeline_tb is    
    
    --Upper level control of testbench
    signal clk : std_logic;
    
    type t_state is (TESTING_BM,TESTING_RSM,TESTING_RSM_PIPELINE_FINISHED);
    signal test_state : t_state := TESTING_BM;
    signal input : std_logic_vector (c_block_size-1 downto 0);
    signal output : std_logic_vector (c_block_size-1 downto 0);
    
    --Spesifics of the BM
    signal rst_bm : std_logic;
    signal a_in_test : std_logic_vector (c_block_size-1 downto 0);
    signal b_in_test : std_logic_vector (c_block_size-1 downto 0);
    signal ab_val : std_logic;
    signal r_out_test : std_logic_vector (c_block_size-1 downto 0);
    signal r_val : std_logic;
    
    
    --Spesifics of the rsm_tester
    signal rsm_tester_en : std_logic := '0';
    signal rst : std_logic;
    
    signal ili : std_logic;
    signal ipi : std_logic;
    signal ipo : std_logic := '0';
    signal ilo : std_logic := '0';
    
    signal dpo : std_logic_vector (c_block_size-1 downto 0);
    signal dci : std_logic_vector (c_block_size-1 downto 0);
    
    --Spesifics of rsm    
    signal rst_rsm : std_logic;
    signal ili_rsm : std_logic;
    signal ipi_rsm : std_logic;
    signal ipo_rsm : std_logic := '0';
    signal ilo_rsm : std_logic := '0';
    
    signal dpo_rsm : std_logic_vector (c_block_size-1 downto 0);
    signal dci_rsm : std_logic_vector (c_block_size-1 downto 0);
    
    signal rsm_status : std_logic_vector(num_status_bits-1 downto 0);

    --Spesifics of rsm_pipeline
    signal rst_rsm_pipeline : std_logic;
    signal ili_rsm_pipeline : std_logic;
    signal ipi_rsm_pipeline : std_logic;
    signal ipo_rsm_pipeline : std_logic := '0';
    signal ilo_rsm_pipeline : std_logic := '0';
    
    signal dpo_rsm_pipeline : std_logic_vector (c_block_size-1 downto 0);
    signal dci_rsm_pipeline : std_logic_vector (c_block_size-1 downto 0);
    
    signal rsm_pipeline_status : std_logic_vector(num_status_bits-1 downto 0);
    
    --Shared modulus and exponent
    signal n : std_logic_vector (c_block_size-1 downto 0);
    signal n_bm : std_logic_vector (c_block_size+1 downto 0);
    signal e : std_logic_vector (c_block_size-1 downto 0);
    
begin
    --Clock generation
    clk_gen : process is
    begin
        while true loop
            clk <= '1';
            wait for CLK_PERIOD/2; 
            clk <= '0';
            wait for CLK_PERIOD/2;
        end loop;
    end process clk_gen;

    --DUT:
    --3 devices under test:
        --Lowest level (Blakeley module)
        --Intermedate level (Single stage of RSA Stage Module)
        --Upper level (Pipeline of RSA Stage Module)
        
    DUT_BM : entity work.blakeley_module(rtl)
    generic map(
       c_block_size => c_block_size
    )
    port map(
        clk => clk,
        rst => rst_bm,
        
        A => a_in_test,
        B => b_in_test,
        N => n_bm,
        ABVAL => ab_val,
        R => r_out_test,
        RVAL => r_val
    );
        
    
    DUT_RSM : entity work.rsa_stage_module
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        num_pipeline_stages => 1,
        log2_es_size => 8,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST => not rst_rsm,
        
        ILI => ilo_rsm,
        IPO => ipi_rsm,
        ILO => ili_rsm,
        IPI => ipo_rsm,
        
        N => n,
        ES => e,

        DPI => dpo_rsm,
        DCI => std_logic_vector(to_unsigned(1, c_block_size)),
        DPO => open,
        DCO => dci_rsm,
        
        rsm_status => rsm_status
    );
    
    DUT_RSM_PIPELINE : entity work.rsa_core_pipeline
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        num_pipeline_stages => 16,
        log2_es_size => 4,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST_N => not rst_rsm_pipeline,
        
        ILI => ilo_rsm_pipeline,
        IPO => ipi_rsm_pipeline,
        ILO => ili_rsm_pipeline,
        IPI => ipo_rsm_pipeline,

        N => n,
        E => e,
        
        DPI => dpo_rsm_pipeline,
        DCI => std_logic_vector(to_unsigned(1, c_block_size)),
        DPO => open,
        DCO => dci_rsm_pipeline,
        
        rsm_status => rsm_pipeline_status
    );
    
    --Standalone test component to test both the single RSM and the pipelined RSM
    RSM_TESTER : entity work.rsm_tester
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        
        num_pipeline_stages => num_pipeline_stages,
        log2_es_size => log2_es_size
    )
    port map(
        tester_en => rsm_tester_en,
        
        clk => clk,
        rst => rst,
        
        --Control signals             
        ili => ili,
        ipi => ipi,
        ipo => ipo,
        ilo => ilo,
        
        --Data signals
        dpo => dpo,
        dci => dci,

        n => n,
        e => e
    );

                
end rtl;
        
    
    

        
        