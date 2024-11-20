library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

use work.tb_utils.all;

entity rsa_tb is
    generic(
        c_block_size : integer := 256;
        log2_c_block_size : integer := 8;
        
        num_pipeline_stages : integer := 16;
        log2_es_size : integer := 4;   --Has to be log2(c_block_size/num_pipeline_stages)
        
        num_status_bits : integer := 32;
        CLK_PERIOD : time := 1 ns        
    );
end rsa_tb;

architecture rtl of rsa_tb is    
    
    --Upper level control of testbench
    signal clk : std_logic;
    
    --Spesifics of the BM
    signal rst_bm : std_logic;
    signal bm_tester_start : std_logic := '0';
    signal bm_tester_finished : std_logic;
    signal a : std_logic_vector (c_block_size-1 downto 0);
    signal b : std_logic_vector (c_block_size-1 downto 0);
    signal abval : std_logic;
    signal r : std_logic_vector (c_block_size-1 downto 0);
    signal rval : std_logic;
    
    
    --Spesifics of the rsm_tester
    type rsm_t is (RSM,RSM_PIPELINE);
    signal rsm_dut : rsm_t := RSM;
    signal rst_tester : std_logic := '0';
    signal rsm_tester_start : std_logic := '0';
    signal rsm_tester_finished : std_logic;
    
    signal rst_rsm_dut : std_logic;
    
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
        
        A => a,
        B => b,
        N => n_bm,
        ABVAL => abval,
        R => r,
        RVAL => rval
    );
        
    
    DUT_RSM : entity work.rsa_core_pipeline
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        num_pipeline_stages => 1,
        log2_es_size => 8,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST_N => not rst_rsm,
        
        ILI => ilo_rsm,
        IPO => ipi_rsm,
        ILO => ili_rsm,
        IPI => ipo_rsm,
        
        N => n,
        E => e,

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
    
    --Standalone test component to test thhe blakeley_module
    BM_TESTER : entity work.bm_tester
    generic map(
        c_block_size => c_block_size
    )
    port map (
        bm_tester_start => bm_tester_start,
        bm_tester_finished => bm_tester_finished,
        
        clk => clk,
        rst_tester => rst_tester,
        rst_dut => rst_bm,
        
        a => a,
        b => b,
        n => n_bm,
        abval => abval,
        r => r,
        rval => rval
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
        rsm_tester_start => rsm_tester_start,
        rsm_tester_finished => rsm_tester_finished,
        
        clk => clk,
        rst_tester => rst_tester,
        rst_dut => rst_rsm_dut,
        
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
    
    distribute_rsm_signals : process(rsm_dut,ili_rsm,ipi_rsm,ili_rsm_pipeline,ipi_rsm_pipeline,ipo,ilo,dpo,dci_rsm,dci_rsm_pipeline,rst_rsm_dut) is
    begin    
        case(rsm_dut) is
            when RSM =>
                rst_rsm <= rst_rsm_dut;
                ili <= ili_rsm;
                ipi <= ipi_rsm;
                ipo_rsm <= ipo;
                ilo_rsm <= ilo;
                
                dpo_rsm <= dpo;
                dci <= dci_rsm;
                
            when RSM_PIPELINE =>
                rst_rsm_pipeline <= rst_rsm_dut;
                ili <= ili_rsm_pipeline;
                ipi <= ipi_rsm_pipeline;
                ipo_rsm_pipeline <= ipo;
                ilo_rsm_pipeline <= ilo;
                
                dpo_rsm_pipeline <= dpo;
                dci <= dci_rsm_pipeline;
        end case;
    end process distribute_rsm_signals;
    
    testbench_control : process is
    begin
        --Control of BM_STAGE_MODULE
        assert false
        report "**********************************Starting test of BM alone**********************************"
        severity note;
        bm_tester_start <= '1';
        wait until bm_tester_finished = '1';
        bm_tester_start <= '0';
        
        rst_tester <= '1';
        wait for 1*CLK_PERIOD;
        rst_tester <= '0';
        
        wait for 10*CLK_PERIOD;
    
        rsm_dut <= RSM;
        assert false
        report "**********************************Starting test of 1-stage RSM alone**********************************"
        severity note;
        rsm_tester_start <= '1';
        wait until rsm_tester_finished = '1';
        rsm_tester_start <= '0';
        
        rst_tester <= '1';
        wait for 1*CLK_PERIOD;
        rst_tester <= '0';
        
        wait for 10*CLK_PERIOD;
        
        rsm_dut <= RSM_PIPELINE;
        assert false
        report "**********************************Starting test of 16-stage RSM pipeline**********************************"
        severity note;
        rsm_tester_start <= '1';
        wait until rsm_tester_finished = '1';
        rsm_tester_start <= '0';
        
        rst_tester <= '1';
        wait for 1*CLK_PERIOD;
        rst_tester <= '0';
        
        wait;
        
    end process testbench_control;
end rtl;
        
    
    

        
        