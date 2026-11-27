library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.divider_pkg.all;

entity div_seq_dsp is
    generic(
        wn          : integer := 5;
        wd          : integer := 3;
        frc         : integer := 0
    );
    Port (
        clk_i       : in std_logic;
        rst_i       : in std_logic;
        ena_i       : in std_logic;
        num_i       : in std_logic_vector(wn-1 downto 0);
        den_i       : in std_logic_vector(wd-1 downto 0);
        busy_o      : out std_logic;
        rdy_o       : out std_logic;
        rem_o       : out std_logic_vector(wd-1 downto 0);
        quot_o      : out std_logic_vector(wn+frc-1 downto 0);
        err_o       : out std_logic
    );
end div_seq_dsp;

architecture Behavioral of div_seq_dsp is

    signal num_s        : std_logic_vector(wn-1 downto 0):=(others => '0');
    signal quot_s       : std_logic_vector(wn+frc-1 downto 0):=(others => '0');
    signal pos_den_s    : signed(DSP_CINP_LEN_C-1 downto 0):=(others => '0');
    signal neg_den_s    : signed(DSP_CINP_LEN_C-1 downto 0):=(others => '0');
    signal add_sub_s    : signed(DSP_CINP_LEN_C-1 downto 0):=(others => '0');

    signal rem_s        : signed(DSP_POUT_LEN_C-1 downto 0):=(others => '0');
    signal pout_s       : std_logic_vector(DSP_POUT_LEN_C-1 downto 0):=(others => '0');

    signal stat_s       : integer range 0 to 3 := 0;
    signal div_ctr_s    : integer range 0 to (wn+frc)-1 := 0;

    signal num_msb_s    : std_logic:= '0';
    signal ena_s        : std_logic:= '0';
    signal clk_ena_s    : std_logic:= '0';
    signal res_rdy_s    : std_logic:= '0';

begin

    DSP_wrapper_INST: entity work.DSP_wrapper
    port map(
        clk_i       => clk_i,
        clk_ena_i   => clk_ena_s,
        rst_i       => rst_i or (ena_i and not ena_s),  -- clear everything in the begining of division
        num_msb_i   => num_msb_s,
        dnum_i      => std_logic_vector(add_sub_s),

        pout_o      => pout_s,
        rdy_o       => res_rdy_s
    );
    num_msb_s       <= num_s((num_s'length - 1) - div_ctr_s) when (div_ctr_s < wn) else '0';
    rem_s           <= signed(pout_s);
    add_sub_s       <= pos_den_s when (rem_s<0) else neg_den_s;

    process(clk_i)
        variable rem_v  : signed(DSP_POUT_LEN_C-1 downto 0):=(others => '0');
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
            
                ena_s       <= '0';
                busy_o      <= '0';
                quot_o      <= (others => '0');
                rem_o       <= (others => '0');
                rdy_o       <= '0';
                err_o       <= '0';
                num_s       <= (others => '0');
                pos_den_s   <= (others => '0');
                rem_v       := (others => '0');
                quot_s      <= (others => '0');
                stat_s      <= 0;
                div_ctr_s   <= 0;
                clk_ena_s   <= '0';
            else
                rdy_o       <= '0';
                 case stat_s is
                    when 0 =>
                        if ena_i = '1' and ena_s = '0' then     -- rising edge sensitive
                            quot_s      <= (others => '0');
                            rem_v       := (others => '0');
                            if unsigned(den_i) =0 then
                                stat_s      <= 2;
                                err_o       <= '1';
                            else
                                num_s       <= num_i;
                                pos_den_s   <= resize(signed('0' & den_i), DSP_CINP_LEN_C);
                                neg_den_s   <= resize(signed(unsigned(not ('0' & den_i)) + 1), DSP_CINP_LEN_C);
                                div_ctr_s   <= 0;
                                stat_s      <= 1;
                                err_o       <= '0';
                                clk_ena_s   <= '1';
                            end if;
                            busy_o          <= '1';
                        end if;
                    when 1 =>
                        if res_rdy_s = '1' then
                            if rem_s < 0 then     -- previous subtraction caused negative remainder
                                quot_s  <= quot_s(quot_s'left-1 downto 0) & '0';
                            else
                                quot_s  <= quot_s(quot_s'left-1 downto 0) & '1';
                            end if;
                        end if;
                        if div_ctr_s < wn+frc-1 then
                            div_ctr_s   <= div_ctr_s + 1;
                        else
                            stat_s      <= 2;
                        end if;
                    when 2 =>
                        clk_ena_s       <= '0';
                        if rem_s < 0 then
                            rem_v       := rem_s + pos_den_s;
                            quot_o      <= quot_s(quot_s'left-1 downto 0) & '0';
                        else
                            rem_v       := rem_s;
                            quot_o      <= quot_s(quot_s'left-1 downto 0) & '1';
                        end if;
                        -- stat_s          <= 3;
                    -- when 3 => 
                    
                        rem_o           <= std_logic_vector(rem_v(wd-1 downto 0));
                        rdy_o           <= '1';
                        busy_o          <= '0';
                        stat_s          <= 0;
                    when others =>
                        null;
                end case;
                ena_s                   <= ena_i;
            end if;
        end if;
    end process;

end Behavioral;
