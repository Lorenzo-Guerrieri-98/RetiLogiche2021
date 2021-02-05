---------------------------------------------------------------------------------- 
-- Student: Lorenzo Guerrieri
-- Create Date: 04.01.2021 20:57:15
-- Module Name: Equalizzatore - Behavioral
-- Project Name: Progetto di Reti Logiche
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity project_reti_logiche is
    Port ( i_clk : in STD_LOGIC;
           i_rst : in STD_LOGIC;
           i_start : in STD_LOGIC;
           i_data : in STD_LOGIC_VECTOR (7 downto 0);
           o_address : out STD_LOGIC_VECTOR (15 downto 0);
           o_done : out STD_LOGIC;
           o_en : out STD_LOGIC;
           o_we : out STD_LOGIC;
           o_data : out STD_LOGIC_VECTOR (7 downto 0));
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is

    type state_type is (IDLE,
                        FETCH_ROWS,
                        WAIT_ROWS, 
                        GET_ROWS, 
                        FETCH_COLUMNS, 
                        WAIT_COLUMNS, 
                        GET_COLUMNS, 
                        FETCH_PIXEL, 
                        WAIT_PIXEL, 
                        GET_PIXEL, 
                        INCREMENT_COUNTER, 
                        START_CONVERSION, 
                        CONVERT_PIXEL, 
                        WRITE_RESULT, 
                        TERMINATE, 
                        RESET);
                        
    signal state              :    state_type := IDLE;
    signal rows               :    std_logic_vector (7 downto 0) := (others => '0');
    signal columns            :    std_logic_vector (7 downto 0) := (others => '0');
    signal min                :    std_logic_vector (7 downto 0) := (others => '1');
    signal max                :    std_logic_vector (7 downto 0):= (others => '0');
    signal counter_rows       :    std_logic_vector (6 downto 0) := (others => '0');
    signal counter_columns    :    std_logic_vector (6 downto 0) := (others => '0');
    signal shift              :    std_logic_vector (3 downto 0) := (others => '0');
    signal conversion_started :    std_logic := '0';
    signal temp_pixel         :    std_logic_vector (15 downto 0) := (others => '0');

begin

    process (i_clk, i_rst)
    begin
        if(i_rst = '1') then
            --Reset output signals
            o_done <= '0';
            o_en <= '0';
            o_we <= '0';
            o_address <= (others => '0');
            o_data <= (others => '0');
            
            --Reset internal signals
            state <= IDLE;
            rows <= (others => '0');
            columns <= (others => '0');
            min <= (others => '1');
            max <= (others => '0');
            counter_rows <= (others => '0');
            counter_columns <= (others => '0');
            shift <= (others => '0');
            conversion_started <= '0';
            temp_pixel <= (others => '0');
            
        elsif (rising_edge(i_clk)) then
            case state is
                when IDLE =>
                    if(i_start = '1') then
                        state <= FETCH_ROWS;
                    end if;
                    
                when FETCH_ROWS =>
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= "0000000000000000"; -- First memory address
                    state <= WAIT_ROWS;
                    
                when WAIT_ROWS =>
                    state <= GET_ROWS;
                    
                when GET_ROWS =>
                    if(i_data = "00000000") then
                        -- If the image has zero width, there is no conversion needed
                        state <= TERMINATE;
                    else
                        rows <= i_data;
                        state <= FETCH_COLUMNS;
                    end if;
                    
                when FETCH_COLUMNS =>
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= "0000000000000001"; -- Second memory address
                    state <= WAIT_COLUMNS;
                    
                when WAIT_COLUMNS =>
                    state <= GET_COLUMNS;
                    
                when GET_COLUMNS =>
                    if(i_data = "00000000") then
                        -- If the image has zero height, there is no conversion needed
                        state <= TERMINATE;
                    else
                        columns <= i_data;
                        state <= FETCH_PIXEL;
                    end if;
                    
                when FETCH_PIXEL =>
                    o_en <= '1';
                    o_we <= '0';
                    o_address <= '0' & std_logic_vector(unsigned(counter_rows)+unsigned(rows)*unsigned(counter_columns)+2);
                    state <= WAIT_PIXEL;
                
                when WAIT_PIXEL =>
                    if(conversion_started = '0') then
                        state <= GET_PIXEL;
                    else
                        state <= CONVERT_PIXEL;
                    end if;
                    
                when GET_PIXEL =>
                    if(unsigned(i_data)<unsigned(min)) then
                        min <= i_data;
                    end if;
                    -- The first pixel will set both max and min, so another if is needed
                    if(unsigned(i_data)>unsigned(max)) then
                        max <= i_data;
                    end if;
                    
                    state <= INCREMENT_COUNTER;
                
                when INCREMENT_COUNTER =>
                    if(unsigned(counter_rows) = unsigned(rows)-1) then
                        --counter-rows reached its maximum value
                        counter_rows <= (others => '0');
                        
                        if(unsigned(counter_columns) = unsigned(columns)-1) then
                            --counter_columns reached its maximum value
                            counter_columns <= (others => '0');
                            
                            if(conversion_started = '0') then
                                state <= START_CONVERSION;
                            else
                                state <= TERMINATE;
                            end if;
                        
                        else
                            counter_columns <= std_logic_vector((unsigned(counter_columns)+1));
                            state <= FETCH_PIXEL;
                        end if;
                    
                    else
                        counter_rows <= std_logic_vector((unsigned(counter_rows)+1));
                        state <= FETCH_PIXEL;
                    end if;
                    
                when START_CONVERSION =>
                    if(unsigned(max)-unsigned(min) = 0) then
                        shift <= "1000";
                    elsif(unsigned(max)-unsigned(min) < 3) then
                        shift <= "0111";
                    elsif(unsigned(max)-unsigned(min) < 7) then
                        shift <= "0110";
                    elsif(unsigned(max)-unsigned(min) < 15) then
                        shift <= "0101";
                    elsif(unsigned(max)-unsigned(min) < 31) then
                        shift <= "0100";
                    elsif(unsigned(max)-unsigned(min) < 63) then
                        shift <= "0011";
                    elsif(unsigned(max)-unsigned(min) < 127) then
                        shift <= "0010";
                    elsif(unsigned(max)-unsigned(min) < 255) then
                        shift <= "0001";
                    else
                        shift <= "0000";
                    end if;
                    conversion_started <= '1';
                    state <= FETCH_PIXEL;                            
                
                when CONVERT_PIXEL =>
                    temp_pixel <= std_logic_vector(shift_left(unsigned("00000000"&i_data) - unsigned("00000000"&min), to_integer(unsigned(shift))));
                    state <= WRITE_RESULT;
                    
                when WRITE_RESULT =>
                    o_address <= std_logic_vector(unsigned(counter_rows)+unsigned(rows)*unsigned(counter_columns)+2+unsigned(rows)*unsigned(columns));
                    if(unsigned(temp_pixel) < 255) then
                        o_data <= temp_pixel(7 downto 0);
                    else
                        o_data <= (others => '1');
                    end if;
                    o_en <= '1';
                    o_we <= '1';
                    state <= INCREMENT_COUNTER;
                    
                when TERMINATE =>
                    o_done <= '1';
                    o_en <= '0';
                    o_we <= '0';
                    
                    state <= RESET;
                
                when RESET =>
                    if(i_start = '1') then
                        -- The module will remain in this state untill i_start is set to 0
                        state <= RESET;
                    else
                        --Reset output signals
                        o_done <= '0';
                        o_en <= '0';
                        o_we <= '0';
                        o_address <= (others => '0');
                        o_data <= (others => '0');
                        
                        --Reset internal signals
                        state <= IDLE;
                        rows <= (others => '0');
                        columns <= (others => '0');
                        min <= (others => '1');
                        max <= (others => '0');
                        counter_rows <= (others => '0');
                        counter_columns <= (others => '0');
                        shift <= (others => '0');
                        conversion_started <= '0';
                        temp_pixel <= (others => '0');
                    end if;
            end case;
        end if;
    end process;
    
end Behavioral;











