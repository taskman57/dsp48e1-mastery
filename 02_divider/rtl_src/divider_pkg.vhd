library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

package divider_pkg is

    constant DSP_CINP_LEN_C     : integer   := 48;
    constant DSP_POUT_LEN_C     : integer   := 48;

    constant X_MUX_C    : std_logic_vector(1 downto 0) := "10";     -- P, must select with PREG=1 pg.34 of UG479 datasheet
    constant Y_MUX_C    : std_logic_vector(1 downto 0) := "11";     -- C, pg.34 of UG479 datasheet
    constant Z_MUX_C    : std_logic_vector(2 downto 0) := "010";    -- P, pg.34 of UG479 datasheet
    constant dsp_mode_c : std_logic_vector(6 downto 0) := Z_MUX_C & Y_MUX_C & X_MUX_C;

    -- This function rounds fix-point numbers to even(convergent rounding)
    -- function conv_round(a: in std_logic_vector; frc_len: in integer) return std_logic_vector;
    function to_hex(slv : std_logic_vector) return string;

end package divider_pkg;

package body divider_pkg is

    function conv_round(a: in std_logic_vector; frc_len: in integer) return std_logic_vector is
        alias a_norm : std_logic_vector(a'length-1 downto 0) is a;
        constant NEG_MAX : std_logic_vector(a'length-1 downto 0) := '1' & (a'length-2 downto 0 => '0');
        constant POS_MAX : std_logic_vector(a'length-1 downto 0) := '0' & (a'length-2 downto 0 => '1');
        variable ret_val    : std_logic_vector(a'length downto 0);
        variable orig_sign  : std_logic;
        variable ovf_sign   : std_logic:='0';
    begin
        ovf_sign    := '0';
        orig_sign   := a(a'left);
        ret_val     := orig_sign & a;
        if frc_len > 0 then     -- fixed-point value (fractional bits present)
            if unsigned(ret_val(frc_len-1 downto 0)) = shift_left(to_unsigned(1,frc_len), frc_len-1) then    -- check if it is equal to 0.5!
                if ret_val(frc_len) = '1' then
                    ret_val(ret_val'left downto frc_len) := std_logic_vector(unsigned(ret_val(ret_val'left downto frc_len))+1);
                end if;
            else
                ret_val := std_logic_vector(unsigned(ret_val) + shift_left(to_unsigned(1,frc_len), frc_len-1));
            end if;
        end if;
        if ret_val(ret_val'left-1) /= ret_val(ret_val'left) then    -- sign bit has changed
            if orig_sign = '0' then
                ret_val(a'left downto 0) := POS_MAX;
            else
                ret_val(a'left downto 0) := NEG_MAX;
            end if;
            ovf_sign    := '1';
        else
            if frc_len > 0 then
                ret_val(frc_len-1 downto 0) := (others => '0');
            end if;
        end if;
        return ovf_sign & ret_val(a'left downto 0);
    end function conv_round;

    -- just for simulation and log into file
    function to_hex(slv : std_logic_vector) return string is
        variable v   : std_logic_vector(slv'length - 1 downto 0) := slv;
        constant nd  : integer := (slv'length + 3) / 4;
        variable pad : std_logic_vector(nd*4 - 1 downto 0) := (others => '0');
        variable nib : std_logic_vector(3 downto 0);
        variable r   : string(1 to nd);
    begin
        pad(v'length - 1 downto 0) := v;
        for i in 0 to nd - 1 loop
            nib := pad(i*4 + 3 downto i*4);
            case nib is
                when "0000" => r(nd-i) := '0';  when "0001" => r(nd-i) := '1';
                when "0010" => r(nd-i) := '2';  when "0011" => r(nd-i) := '3';
                when "0100" => r(nd-i) := '4';  when "0101" => r(nd-i) := '5';
                when "0110" => r(nd-i) := '6';  when "0111" => r(nd-i) := '7';
                when "1000" => r(nd-i) := '8';  when "1001" => r(nd-i) := '9';
                when "1010" => r(nd-i) := 'A';  when "1011" => r(nd-i) := 'B';
                when "1100" => r(nd-i) := 'C';  when "1101" => r(nd-i) := 'D';
                when "1110" => r(nd-i) := 'E';  when "1111" => r(nd-i) := 'F';
                when others => r(nd-i) := 'X';
            end case;
        end loop;
        return r;
    end function;

end package body divider_pkg;