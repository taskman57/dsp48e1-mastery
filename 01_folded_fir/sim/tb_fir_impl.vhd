library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.math_real.uniform;
use IEEE.math_real.floor;

entity tb_fir_impl is
    generic(data_width_g    : integer := 16);
end tb_fir_impl;

architecture sim of tb_fir_impl is

    ----Input
    signal clk_i            : STD_LOGIC:='1';
    signal data_i           : STD_LOGIC_VECTOR(data_width_g-1 downto 0):=(others => '0');

    ---- output
    signal sfr_dat_o        : STD_LOGIC_VECTOR(data_width_g-1 downto 0);

    ---- constants
    constant clk_per_c      : time  := 10 ns;  


begin

    DUT: entity work.fir_impl
    generic map(
        fir_tap_g       => 50,
        data_width_g    => data_width_g
    )
    port map(
        clk_i       => clk_i,
        data_i      => data_i,
        sfr_dat_o   => sfr_dat_o
    );

    clk_gen: process
    begin
        while true loop
            clk_i <= not clk_i;
            wait for clk_per_c/2;
        end loop;
    end process;

    stimulus: process
        variable ctr_v  : integer:=32-1;
        variable seed1  : positive:=4236;
        variable seed2  : positive:=819001;
        variable x_val  : real;
    begin
        while true loop
            wait until rising_edge(clk_i);
                if ctr_v >0 then
                    uniform(seed1, seed2, x_val);
                    data_i      <= std_logic_vector(to_unsigned(integer(floor(real(2**data_i'length - 1) * x_val)),data_i'length));
                    ctr_v       := ctr_v - 1;
                end if;
        end loop;
    end process;
end sim;
