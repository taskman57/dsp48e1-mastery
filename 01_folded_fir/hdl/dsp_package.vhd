library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package dsp_pkg is

    constant ADC_BIT_RES_C      : integer   := 16;
    constant FIR_LEN_C          : integer   := 50;
    constant DSP_LATANCY_C      : integer   := 4;   -- 2 FFs before multiplier + 1 (after multiplier) + 1 (after ALU)
    constant PULSE_SAMPLES_C    : integer   := 2500;

    type sfr_fir_t is array(FIR_LEN_C-2 downto 0) of signed(ADC_BIT_RES_C-1 downto 0);
    type chrp_rom_t     is array(natural range <>) of signed(ADC_BIT_RES_C-1 downto 0);

    type noisy_dat_t    is array(natural range <>) of signed(ADC_BIT_RES_C-1 downto 0);
    type fir_coef_t     is array(0 to FIR_LEN_C/2-1) of signed(ADC_BIT_RES_C-1 downto 0);

    constant fir_coef_c     : fir_coef_t    :=(
        to_signed(59, 16),
        to_signed(55, 16),
        to_signed(79, 16),
        to_signed(108, 16),
        to_signed(143, 16),
        to_signed(184, 16),
        to_signed(232, 16),
        to_signed(285, 16),
        to_signed(345, 16),
        to_signed(410, 16),
        to_signed(480, 16),
        to_signed(553, 16),
        to_signed(630, 16),
        to_signed(709, 16),
        to_signed(788, 16),
        to_signed(866, 16),
        to_signed(942, 16),
        to_signed(1015, 16),
        to_signed(1082, 16),
        to_signed(1143, 16),
        to_signed(1195, 16),
        to_signed(1239, 16),
        to_signed(1273, 16),
        to_signed(1295, 16),
        to_signed(1274, 16)
    );

    constant noisy_dat_c    : noisy_dat_t   :=(
        x"FFF8",
        x"FD19",
        x"F4DC",
        x"E857",
        x"D92E",
        x"C957",
        x"BAD3",
        x"AF6C",
        x"A86C",
        x"A675",
        x"A96C",
        x"B075",
        x"BA1D",
        x"C485",
        x"CDAC",
        x"D3B6",
        x"D52F",
        x"D13E",
        x"C7C8",
        x"B972",
        x"A78C",
        x"93DE",
        x"8071",
        x"6F3F",
        x"61EF",
        x"599D",
        x"56AF",
        x"58CA",
        x"5EDF",
        x"6750",
        x"702E",
        x"777D",
        x"7B7F",
        x"7AED",
        x"752E",
        x"6A66",
        x"5B77",
        x"49DE",
        x"3781",
        x"2668",
        x"1878",
        x"0F2E",
        x"0B6A",
        x"0D4E",
        x"143D",
        x"1EF0",
        x"2BA4",
        x"3859",
        x"431B",
        x"4A48",
        x"4CCD",
        x"4A48",
        x"431B",
        x"3859",
        x"2BA4",
        x"1EF0",
        x"143D",
        x"0D4E",
        x"0B6A",
        x"0F2E",
        x"1878",
        x"2668",
        x"3781",
        x"49DE",
        x"5B77",
        x"6A66",
        x"752E",
        x"7AED",
        x"7B7F",
        x"777D",
        x"702E",
        x"6750",
        x"5EDF",
        x"58CA",
        x"56AF",
        x"599D",
        x"61EF",
        x"6F3F",
        x"8071",
        x"93DE",
        x"A78C",
        x"B972",
        x"C7C8",
        x"D13E",
        x"D52F",
        x"D3B6",
        x"CDAC",
        x"C485",
        x"BA1D",
        x"B075",
        x"A96C",
        x"A675",
        x"A86C",
        x"AF6C",
        x"BAD3",
        x"C957",
        x"D92E",
        x"E857",
        x"F4DC",
        x"FD19"
    );

    constant DSP_AINP_LEN_C     : integer   := 30;
    constant DSP_BINP_LEN_C     : integer   := 18;
    constant DSP_CINP_LEN_C     : integer   := 48;
    constant DSP_POUT_LEN_C     : integer   := 48;
    constant DSP_DINP_LEN_C     : integer   := 25;

    type ainp_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(DSP_AINP_LEN_C-1 downto 0);
    type binp_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(DSP_BINP_LEN_C-1 downto 0);
    type pcin_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(DSP_CINP_LEN_C-1 downto 0);
    type pout_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(DSP_POUT_LEN_C-1 downto 0);
    type dinp_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(DSP_DINP_LEN_C-1 downto 0);
    type dsp_mode_t is array(0 to FIR_LEN_C/2-1) of std_logic_vector(06 downto 0);

    -- This function rounds fix-point numbers to even(convergent rounding)
    function conv_round(a: in std_logic_vector; frc_len: in integer) return std_logic_vector;

end package dsp_pkg;

package body dsp_pkg is

function conv_round(a: in std_logic_vector; frc_len: in integer) return std_logic_vector is
    constant NEG_MAX    : std_logic_vector(a'length-1 downto 0) :=(a'high => '1', others => '0');
    constant POS_MAX    : std_logic_vector(a'length-1 downto 0) :=(a'high => '0', others => '1');
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

end package body dsp_pkg;