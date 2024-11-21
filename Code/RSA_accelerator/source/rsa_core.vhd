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
        
        --To change the number of cores, change ALL four below:
        num_pipeline_stages : integer := 16;
        e_block_size : integer := 256;         --es_size*num_pipeline_stages     
        es_size : integer := 16;
        log2_es_size : integer := 4;  
        
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
    type pc_state is (COUNT,SAVE);
    signal performance_counter_state : pc_state := COUNT;
    signal num_cycles_last_case : unsigned(15 downto 0) := to_unsigned(0,16);
    signal clk_counter : unsigned(15 downto 0) := to_unsigned(0,16);


    --States
    type ai_state is (GET_FROM_AXI,HOLD_FOR_PIPELINE);
    type ao_state is (WAIT_FOR_PIPELINE,GIVE_TO_AXI,SIGNAL_PIPELINE);
    signal axi_in_state : ai_state := GET_FROM_AXI;
    signal axi_in_state_nxt : ai_state := GET_FROM_AXI;
    signal axi_out_state : ao_state := WAIT_FOR_PIPELINE;
    signal axi_out_state_nxt : ao_state := WAIT_FOR_PIPELINE;

    --The signal message_counter_target is a signal axi_in writes message_counter_in to, upon sending testcases to the pipeline at entry message_counter_target_wr_ptr.
    --Once the msgin_last signal is asserted into axi_in, the write counter is incremetned, making the axi_in to write another entry in the message_counter_target structure.
    --The message_counter_target is read by the axi_out module at entry message_counter_target_rd_ptr. As the axi_in module constantly lies num_pipeline_stages ahead of the 
    --axi out module if rd_ptr=wr_ptr, the axi_out read of the message_counter_target will match what the input wrote, only when it is it's last message out. This is what the
    --assertion of msgout_last is based off.
    type fifo_counter is array (num_pipeline_stages downto 0) of unsigned(log2_max_message_count-1 downto 0);
    signal message_counter_target : fifo_counter;
    signal message_counter_target_nxt : fifo_counter;
    
    signal message_counter_in : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
    signal message_counter_in_nxt : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
    signal message_counter_target_wr_ptr : integer := 0;
    signal message_counter_target_wr_ptr_nxt : integer := 0;
    
    signal message_counter_out : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
    signal message_counter_out_nxt : unsigned(log2_max_message_count-1 downto 0) := to_unsigned(0,log2_max_message_count);
    signal message_counter_target_rd_ptr : integer := 0;
    signal message_counter_target_rd_ptr_nxt : integer := 0;
    
    --Common values for all stages comupted once here to save luts
    signal nx1 : std_logic_vector(c_block_size+1 downto 0);
    signal nx2 : std_logic_vector(c_block_size+1 downto 0);
    signal e_extended : std_logic_vector(e_block_size-1 downto 0);
    
    --Circular increment to realize the fifo increment of the rd_ptr and wr_ptr
    function circular_increment(ptr : integer; max_value : integer) return integer is
    begin
        if ptr >= max_value then
            return 0;
        else
            return ptr + 1;
        end if;
    end function;
begin
    rsa_status <= std_logic_vector(num_cycles_last_case) & rsm_status(15 downto 0);
    e_extended <= std_logic_vector(resize(unsigned(key_e_d),e_extended'length));
    nx1 <= std_logic_vector("00" & key_n);
    nx2 <= std_logic_vector(unsigned(nx1) sll 1);
    
    --Iterface to AXI input stream
    axi_in : process(ipi,axi_in_state,msgin_last,msgin_valid,message_counter_in,message_counter_target,message_counter_target_wr_ptr) is
        
    begin
        message_counter_target_nxt <= message_counter_target;
        message_counter_target_wr_ptr_nxt <= message_counter_target_wr_ptr;
        message_counter_in_nxt <= message_counter_in;
        case axi_in_state is
            --PURPOSE OF STATE:
            --Wait for the next message from the axi in stream
            --Signaling to the first stage that this "virtual" stage (axi_in) has reached its IDLE (ilo = 0)
            when GET_FROM_AXI =>
                --Signal to next stage that axi_in is entering IDLE and is open for new data
                ilo <= '0';
                msgin_ready <= '0';
                                
                --Enter hold state for next stage if it is ready for new values (ipi = '0') and data in is valid (msgin_valid = '1')
                if ipi = '0' and msgin_valid = '1' then
                    message_counter_in_nxt <= message_counter_in + 1;
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                else
                    axi_in_state_nxt <= GET_FROM_AXI;
                end if;
            
            --PURPOSE OF STATE:
            --Hold the value, now ready on the axi lines, until the first stage has clocked them in.
            --Done by signaling ilo = '1' then waiting for the ack of ipi = '1'
            when HOLD_FOR_PIPELINE =>
                --Signal to next stage that data is valid
                ilo <= '1';
                
                --Enter GET_FROM_AXI state for axi_in only if next stage has taken over the values on the axi_in bus
                if(ipi = '1') then
                    axi_in_state_nxt <= GET_FROM_AXI;
                    msgin_ready <= '1';
                    if msgin_last = '1' then
                        message_counter_target_nxt(message_counter_target_wr_ptr) <= message_counter_in;
                        message_counter_target_wr_ptr_nxt <= circular_increment(message_counter_target_wr_ptr,num_pipeline_stages);
                        message_counter_in_nxt <= to_unsigned(0,log2_max_message_count);
                    else
                        --Prevents the axi_out module of reading a previous, incomplete message_counter when wr_ptr = rd_ptr
                        --The axi_out module can never reach the state of checking message_counter_target, without having incremented its message_counter_out (it has always received a message from the axi when getting here)
                        message_counter_target_nxt(message_counter_target_wr_ptr) <= to_unsigned(0,log2_max_message_count);
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
        num_pipeline_stages => num_pipeline_stages,
        e_block_size => e_block_size,
        es_size => es_size,
        log2_es_size => log2_es_size,
        num_status_bits => num_status_bits
    )
    port map(
        CLK => clk,
        RST_N => reset_n,
        
        --Input control signals to the blakeley stage module are outputs from the tb
        ILI => ilo,
        IPI => ipo,
        
        --Output control signals from the blakeley stage module are inputs to the tb
        IPO => ipi,
        ILO => ili,
        
        NX1 => nx1,
        NX2 => nx2,
        E => e_extended,
        
        DPI => msgin_data,
        DCI => std_logic_vector(to_unsigned(1, c_block_size)), --The first c has to be 1, see high level model
        DPO => open,--Value are not in use, see high level model
        DCO => msgout_data,
        
        rsm_status => rsm_status
    );
    
    update_performance_counter : process(clk, ili) is
    begin
        if (clk'event and clk = '1') then
            clk_counter <= clk_counter + 1;
        end if;
        if (ili'event and ili = '1') then
            num_cycles_last_case <= clk_counter;
        end if;
        if ili'event and ili = '0' then
            clk_counter <= (others => '0');
        end if;
    end process update_performance_counter;
    
    --Iterface to AXI output stream
    axi_out : process(ili,axi_out_state,msgout_ready,message_counter_out,message_counter_target,message_counter_target_rd_ptr) is
        
    begin
        case(axi_out_state) is
            
            --PURPOSE OF STATE:
            --Wait for the last stage in the pipeline to assert its ili, axi_out's ilo. 
            --Enter the state give_to_axi if avalibale
            when WAIT_FOR_PIPELINE =>
                --Signal to last stage that axi_out is ready for new values
                ipo <= '0';
                msgout_valid <= '0';
                msgout_last <= '0';
                message_counter_target_rd_ptr_nxt <= message_counter_target_rd_ptr;
                
                if ili = '1' then
                    message_counter_out_nxt <= message_counter_out + 1;
                    axi_out_state_nxt <= GIVE_TO_AXI;
                else
                    message_counter_out_nxt <= message_counter_out;
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;
                end if;
                
            --PURPOSE OF STATE:
            --Give the value to axi, done by asserting valid and waiting for the ready signal in return
            when GIVE_TO_AXI =>
                ipo <= '0';
                msgout_valid <= '1';
                if message_counter_out = message_counter_target(message_counter_target_rd_ptr) then
                    msgout_last <= '1';
                else
                    msgout_last <= '0';
                end if;
                message_counter_target_rd_ptr_nxt <= message_counter_target_rd_ptr;
                message_counter_out_nxt <= message_counter_out;

                if msgout_ready = '1' then
                    axi_out_state_nxt <= SIGNAL_PIPELINE;
                else
                    axi_out_state_nxt <= GIVE_TO_AXI;
                end if;
            
            --PURPOSE OF STATE:
            --Acknowledge to the last pipeline stage thatthat axi_out don't need its values anymore, done by singnaling ipo=1 (intermidates popped out)
            --The last stage should acknowledge on that by returning to IDLE, setting ilo=0
            when SIGNAL_PIPELINE =>
                ipo <= '1';
                msgout_valid <= '0';
                msgout_last <= '0';
                message_counter_out_nxt <= message_counter_out;
                message_counter_target_rd_ptr_nxt <= message_counter_target_rd_ptr;
                
                if ili = '0' then
                    if message_counter_out = message_counter_target(message_counter_target_rd_ptr) then
                        message_counter_out_nxt <= to_unsigned(0,log2_max_message_count);
                        message_counter_target_rd_ptr_nxt <= circular_increment(message_counter_target_rd_ptr,num_pipeline_stages);
                    end if;
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
            
            message_counter_target <= message_counter_target_nxt;
            message_counter_in <= message_counter_in_nxt;
            message_counter_target_wr_ptr <= message_counter_target_wr_ptr_nxt;
            message_counter_out <= message_counter_out_nxt;
            message_counter_target_rd_ptr <= message_counter_target_rd_ptr_nxt;
        end if;
    end process fsm_seq;
end rtl;
