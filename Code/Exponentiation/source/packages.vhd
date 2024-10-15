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

