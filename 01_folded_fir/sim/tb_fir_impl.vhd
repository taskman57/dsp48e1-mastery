library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;
use IEEE.math_real.uniform;
use IEEE.math_real.floor;
use work.dsp_pkg.all;
use STD.textio.all;
use ieee.std_logic_textio.all;

entity tb_fir_impl is
end tb_fir_impl;

architecture sim of tb_fir_impl is

    ----Input
    signal clk_i            : STD_LOGIC:='1';
    signal rst_i            : STD_LOGIC:='1';
    signal data_i           : STD_LOGIC_VECTOR(ADC_BIT_RES_C-1 downto 0):=(others => '0');
    signal coef_i           : fir_coef_t;

    ---- output
    signal sfr_dat_o        : STD_LOGIC_VECTOR(ADC_BIT_RES_C-1 downto 0);
    signal prod_res_o       : STD_LOGIC_VECTOR(ADC_BIT_RES_C-1 downto 0);
    signal fir_vld_o        : std_logic;
    ---- constants
    constant clk_per_c      : time  := 10 ns;  

    file rtl_dsp_fir        : text;
begin
    file_open(rtl_dsp_fir, "../../../../../sim/output_results.dat", write_mode);

    DUT: entity work.fir_impl
    port map(
        clk_i       => clk_i,
        rst_i       => rst_i,
        data_i      => data_i,
        coef_i      => coef_i,
        sfr_dat_o   => sfr_dat_o,
        prod_res_o  => prod_res_o,
        fir_vld_o   => fir_vld_o
    );

    clk_gen: process
    begin
        while true loop
            clk_i <= not clk_i;
            wait for clk_per_c/2;
        end loop;
    end process;

    rst_stim: process
    begin
        rst_i   <= '0' after clk_per_c*2.1;
        wait;
    end process;

    coef_i      <= fir_coef_c;

    stimulus: process(clk_i)
        variable ctr_v  : integer := 0;
        variable lin_v  : line;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                data_i  <= (others => '0');
                ctr_v   := 0;
            else
                data_i  <= std_logic_vector(noisy_dat_c(ctr_v) - 32768);
                if ctr_v < 100-1 then
                    ctr_v   := ctr_v + 1;
                else
                    ctr_v   := 0;
                end if;
                if fir_vld_o = '1' then
                    report "Writing FIR result";
                    hwrite(lin_v, prod_res_o);
                    writeline(rtl_dsp_fir, lin_v);
                end if;
            end if;
        end if;
    end process;
end sim;
