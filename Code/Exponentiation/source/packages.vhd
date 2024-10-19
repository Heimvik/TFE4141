library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


-- IMPORTANT: MUST be compiled before anything it is used in!
package blakeley_utils is
    function mod_mult(A, B, N : integer) return integer;
end package blakeley_utils;

package body blakeley_utils is
    function mod_mult(A, B, N : integer) return integer is
        variable result : integer;
    begin
        result := (A * B) mod N;
        return result;
    end function;
end package body blakeley_utils;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use std.textio.all;

package tb_utils is
    function string_to_unsigned(s: string) return unsigned;
    function get_unsigned(line_in: in string; position: in integer) return string;
    function vectors_equal(base : in std_logic_vector(255 downto 0);compareand : in std_logic_vector(255 downto 0)) return boolean;
end package tb_utils;

package body tb_utils is
    function vectors_equal(base : in std_logic_vector(255 downto 0);compareand : in std_logic_vector(255 downto 0)) return boolean is
        variable i : integer;
    begin
        for i in 0 to 255 loop
            if base(i) /= compareand(i) then
                return false;
            end if;
        end loop;
        return true;
    end function vectors_equal;


    function string_to_unsigned(s: string) return unsigned is
        variable result: unsigned(255 downto 0) := (others => '0');
        variable digit: unsigned(3 downto 0);
    begin
        for i in s'range loop
            if s(i) >= '0' and s(i) <= '9' then
                digit := to_unsigned(character'pos(s(i)) - character'pos('0'), 4);
                result := result * 10 + digit;  -- Shift left and add digit
            else
                report "Non-numeric character in input string" severity error;
            end if;
        end loop;
        return result;
    end function;

    function get_unsigned(line_in: in string; position: in integer) return string is
        variable start_pos : integer := 1;
        variable end_pos : integer := 1;
        variable comma_count : integer := 0;
        variable res : string(1 to 256);
        variable i : integer;
    begin
        for i in line_in'range loop
            if(line_in(i) = ',') then
                --Once we reach a new comma, we have two possebilities:
                    --comma_count = position gives start_pos at i+1
                    --comma_count = position+1 gives end_pos at i-1 then exit
                comma_count := comma_count + 1;
                if(comma_count = position) then
                    start_pos := i+1;
                end if;
                if(comma_count = position+1) then
                    end_pos := i-1;
                    exit;
                end if;
            end if;
        end loop;
        res := line_in(start_pos to end_pos);
        
        return res;
    end function;
end package body tb_utils;
