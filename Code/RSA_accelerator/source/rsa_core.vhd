--------------------------------------------------------------------------------
-- Author       : Oystein Gjermundnes
-- Organization : Norwegian University of Science and Technology (NTNU)
--                Department of Electronic Systems
--                https://www.ntnu.edu/ies
-- Course       : TFE4141 Design of digital systems 1 (DDS1)
-- Year         : 2018-2019
-- Project      : RSA accelerator
-- License      : This is free and unencumbered software released into the
--                public domain (UNLICENSE)
--------------------------------------------------------------------------------
-- Purpose:
--   RSA encryption core template. This core currently computes
--   C = M xor key_n
--
--   Replace/change this module so that it implements the function
--   C = M**key_e mod key_n.
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity rsa_core is
	generic (
        c_block_size : integer  := 256;
        c_pipeline_stages : integer := 16;
        log2_c_block_size : integer := 8;
        log2_max_message_count : integer := 16;
        num_status_bits : integer := 32
	);
	port (
		-----------------------------------------------------------------------------
		-- Clocks and reset
		-----------------------------------------------------------------------------
		clk                    :  in std_logic;
		reset_n                :  in std_logic;

		-----------------------------------------------------------------------------
		-- Slave msgin interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgin_valid             : in std_logic;
		-- Slave ready to accept a new message
		msgin_ready             : out std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgin_data              :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		-- Indicates boundary of last packet
		msgin_last              :  in std_logic;

		-----------------------------------------------------------------------------
		-- Master msgout interface
		-----------------------------------------------------------------------------
		-- Message that will be sent out is valid
		msgout_valid            : out std_logic;
		-- Slave ready to accept a new message
		msgout_ready            :  in std_logic;
		-- Message that will be sent out of the rsa_msgin module
		msgout_data             : out std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		-- Indicates boundary of last packet
		msgout_last             : out std_logic;

		-----------------------------------------------------------------------------
		-- Interface to the register block
		-----------------------------------------------------------------------------
		key_e_d                 :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		key_n                   :  in std_logic_vector(C_BLOCK_SIZE-1 downto 0);
		rsa_status              : out std_logic_vector(num_status_bits-1 downto 0)
	);
end rsa_core;

architecture rtl of rsa_core is
    --Control signals             
    signal ili : std_logic;
    signal ipi : std_logic;
    signal ipo : std_logic := '0';
    signal ilo : std_logic := '0';
    
    --Status registers
    signal rsm_status : std_logic_vector(num_status_bits-1 downto 0);
    signal bm_status : std_logic_vector(num_status_bits-1 downto 0);

    --States
    type ai_state is (GET_FROM_AXI,HOLD_FOR_PIPELINE);
    type ao_state is (WAIT_FOR_PIPELINE,GIVE_TO_AXI,SIGNAL_PIPELINE);
    signal axi_in_state : ai_state := GET_FROM_AXI;
    signal axi_in_state_nxt : ai_state := GET_FROM_AXI;
    signal axi_out_state : ao_state := WAIT_FOR_PIPELINE;
    signal axi_out_state_nxt : ao_state := WAIT_FOR_PIPELINE;

    type fifo_counter is array (c_pipeline_stages-1 downto 0) of unsigned(log2_max_message_count-1 downto 0);
    signal message_counter_target : fifo_counter;
    
    function inc_or_mod(ptr : integer; max_value : integer) return integer is
    begin
        if ptr >= max_value then
            return 0;
        else
            return ptr + 1;
        end if;
    end function;
begin
    --Iterface to AXI input stream
    axi_in : process(ipi,axi_in_state,msgin_valid) is
        variable message_counter_in : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
        variable message_counter_target_wr_ptr : integer := 0;
    begin
        case axi_in_state is
            when GET_FROM_AXI =>
                --Signal to next stage that axi_in is entering IDLE and is open for new data
                ilo <= '0';
                msgin_ready <= '0';
                                
                --Enter hold state for next stage if it is ready for new values (ipi = '0') and data in is valid (msgin_valid = '1')
                if ipi = '0' and msgin_valid = '1' then
                    message_counter_in := message_counter_in + 1;
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                else
                    message_counter_in := message_counter_in;
                    axi_in_state_nxt <= GET_FROM_AXI;
                end if;
            
            when HOLD_FOR_PIPELINE =>
                --Signal to next stage that data is valid
                ilo <= '1';
                
                --Enter GET_FROM_AXI state for axi_in only if next stage has taken over the values on the axi_in bus
                if(ipi = '1') then
                    axi_in_state_nxt <= GET_FROM_AXI;
                    msgin_ready <= '1';
                    if msgin_last = '1' then
                        message_counter_target(message_counter_target_wr_ptr) <= message_counter_in;
                        message_counter_target_wr_ptr := inc_or_mod(message_counter_target_wr_ptr,c_pipeline_stages-1);
                        message_counter_in := to_unsigned(0,log2_max_message_count);
                    end if;
                else
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                    msgin_ready <= '0';
                end if;
        end case;
    end process axi_in;

    rsa_pipeline : entity work.rsa_core_pipeline
    generic map(
        c_block_size => c_block_size,
        log2_c_block_size => log2_c_block_size,
        c_pipeline_stages => c_pipeline_stages,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST => reset_n,
        
        --Input control signals to the blakeley stage module are outputs from the tb
        ILI => ilo,
        IPI => ipo,
        
        --Output control signals from the blakeley stage module are inputs to the tb
        IPO => ipi,
        ILO => ili,
        
        N => key_n,
        E => key_e_d,
        
        DPI => msgin_data,
        DCI => std_logic_vector(to_unsigned(1, c_block_size)),
        DPO => open,
        DCO => msgout_data,
        
        rsm_status => rsa_status
    );
    
    --Iterface to AXI output stream
    axi_out : process(ili,axi_out_state,msgout_ready) is
        variable message_counter_out : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
        variable message_counter_target_rd_ptr : integer := 0;
    begin
        case(axi_out_state) is
            when WAIT_FOR_PIPELINE =>
                --Signal to previous stage that axi_out is ready for new values
                ipo <= '0';
                msgout_valid <= '0';

                if ili = '1' then
                    message_counter_out := message_counter_out + 1;
                    axi_out_state_nxt <= GIVE_TO_AXI;
                else
                    message_counter_out := message_counter_out;
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;
                end if;
            when GIVE_TO_AXI =>
                ipo <= '0';
                msgout_valid <= '1';
                if message_counter_out = message_counter_target(message_counter_target_rd_ptr) then
                    msgout_last <= '1';
                else
                    msgout_last <= '0';
                end if;
                
                if msgout_ready = '1' then
                    axi_out_state_nxt <= SIGNAL_PIPELINE;
                else
                    axi_out_state_nxt <= GIVE_TO_AXI;
                end if;
                
            when SIGNAL_PIPELINE =>
                ipo <= '1';
                msgout_valid <= '0';
                msgout_last <= '0';
                if message_counter_out = message_counter_target(message_counter_target_rd_ptr) then
                    message_counter_target_rd_ptr := inc_or_mod(message_counter_target_rd_ptr,c_pipeline_stages-1);
                    message_counter_out := to_unsigned(0,log2_max_message_count);
                end if;
                if ili = '0' then
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;
                else
                    axi_out_state_nxt <= SIGNAL_PIPELINE;
                end if;
        end case;
    end process axi_out;
    
    fsm_seq : process(clk) is
    begin
        if (clk'event and clk='1') then
            axi_in_state <= axi_in_state_nxt;
            axi_out_state <= axi_out_state_nxt;
            
            --message_counter_in <= message_counter_in_nxt;
            --message_counter_target <= message_counter_target_nxt;
        end if;
    end process fsm_seq;
end rtl;
