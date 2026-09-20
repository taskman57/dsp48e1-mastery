library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fir_impl is
    generic(
        fir_tap_g       : integer := 54;
        data_width_g    : integer := 16
    );
    Port ( 
        clk_i       : in STD_LOGIC;
        data_i      : in STD_LOGIC_VECTOR (data_width_g-1 downto 0);
        sfr_dat_o   : out STD_LOGIC_VECTOR(data_width_g-1 downto 0)
    );
end fir_impl;

architecture Behavioral of fir_impl is

    attribute shreg_extract : string;
    attribute srl_style     : string;

    type sfr_fir_t is array(fir_tap_g-1 downto 0) of std_logic_vector(data_width_g-1 downto 0);

    signal sfr_reg_s        : sfr_fir_t := (others => (others => '0'));
    attribute shreg_extract of sfr_reg_s    : signal is "yes";
    attribute srl_style     of sfr_reg_s    : signal is "srl";  -- no register before or after

begin

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            for i in fir_tap_g-1 downto 1 loop
                sfr_reg_s(i)    <= sfr_reg_s(i-1);
            end loop;
            sfr_reg_s(0)        <= data_i;
        end if;
    end process;
    sfr_dat_o       <= sfr_reg_s(fir_tap_g-1);

end Behavioral;
