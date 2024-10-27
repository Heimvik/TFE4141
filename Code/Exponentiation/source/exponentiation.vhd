library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity exponentiation is
	generic (
        c_block_size : integer  := 256;
        log2_c_block_size : integer := 8;
        c_pipeline_stages : integer := 16;
        num_status_bits : integer := 32
	);
	port (
		--input controll
		valid_in	: in STD_LOGIC;
		ready_in	: out STD_LOGIC;

		--input data
		message 	: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );
		key 		: in STD_LOGIC_VECTOR ( C_block_size-1 downto 0 );

		--ouput controll
		ready_out	: in STD_LOGIC;
		valid_out	: out STD_LOGIC;

		--output data
		result 		: out STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--modulus
		modulus 	: in STD_LOGIC_VECTOR(C_block_size-1 downto 0);

		--utility
		clk 		: in STD_LOGIC;
		reset_n 	: in STD_LOGIC
	);
end exponentiation;


architecture expBehave of exponentiation is
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
begin
    --Iterface to AXI input stream
    axi_in : process(ipi,axi_in_state,valid_in) is
    begin
        case axi_in_state is
            when GET_FROM_AXI =>
                --Signal to next stage that axi_in is entering IDLE and is open for new data
                ilo <= '0';
                ready_in <= '0';
                                
                --Enter hold state for next stage if it is ready for new values (ipi = '0') and data in is valid (valid_in = '1')
                if ipi = '0' and valid_in = '1' then
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                else
                    axi_in_state_nxt <= GET_FROM_AXI;
                end if;
            
            when HOLD_FOR_PIPELINE =>
                --Signal to next stage that data is valid
                ilo <= '1';
                
                --Enter GET_FROM_AXI state for axi_in only if next stage has taken over the values on the axi_in bus
                if(ipi = '1') then
                    axi_in_state_nxt <= GET_FROM_AXI;
                    ready_in <= '1';
                else
                    axi_in_state_nxt <= HOLD_FOR_PIPELINE;
                    ready_in <= '0';
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
        
        N => modulus,
        E => key,
        
        DPI => message,
        DCI => std_logic_vector(to_unsigned(1, c_block_size)),
        DPO => open,
        DCO => result,
        
        rsm_status => rsm_status,
        bm_status => bm_status
    );
    
    --Iterface to AXI output stream
    axi_out : process(ili,axi_out_state,ready_out) is
    begin
        case(axi_out_state) is
            when WAIT_FOR_PIPELINE =>
                --Signal to previous stage that axi_out is ready for new values
                ipo <= '0';
                valid_out <= '0';

                if ili = '1' then
                    axi_out_state_nxt <= GIVE_TO_AXI;
                else
                    axi_out_state_nxt <= WAIT_FOR_PIPELINE;
                end if;
            
            when GIVE_TO_AXI =>
                ipo <= '0';
                valid_out <= '1';
                
                if ready_out = '1' then
                    axi_out_state_nxt <= SIGNAL_PIPELINE;
                else
                    axi_out_state_nxt <= GIVE_TO_AXI;
                end if;
                
            when SIGNAL_PIPELINE =>
                ipo <= '1';
                valid_out <= '0';
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
        end if;
    end process fsm_seq;
end expBehave;