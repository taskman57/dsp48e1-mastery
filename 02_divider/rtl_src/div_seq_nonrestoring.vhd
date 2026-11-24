library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity div_seq_nonrestoring is
    generic(
        wn          : integer := 5;
        wd          : integer := 3;
        frc         : integer := 3
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
end div_seq_nonrestoring;

architecture Behavioral of div_seq_nonrestoring is

    signal num_s        : std_logic_vector(wn-1 downto 0):=(others => '0');
    signal quot_s       : std_logic_vector(wn+frc-1 downto 0):=(others => '0');
    signal den_s        : signed(wd+1 downto 0):=(others => '0');

    signal stat_s       : integer range 0 to 3 := 0;
    signal div_ctr_s    : integer range 0 to (wn+frc)-1 := 0;

    signal ena_s        : std_logic:= '0';

begin

    process(clk_i)
        variable rem_v  : signed(wd+1 downto 0):=(others => '0');
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
                den_s       <= (others => '0');
                rem_v       := (others => '0');
                quot_s      <= (others => '0');
                stat_s      <= 0;
                div_ctr_s   <= 0;
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
                                den_s       <= signed("00" & den_i);
                                div_ctr_s   <= 0;
                                stat_s      <= 1;
                                err_o       <= '0';
                            end if;
                            busy_o          <= '1';
                        end if;
                    when 1 =>       -- 2R+bit
                        if div_ctr_s < wn then
                            rem_v   := rem_v(rem_v'left-1 downto 0) & num_s(num_s'left);
                        else
                            rem_v   := rem_v(rem_v'left-1 downto 0) & '0';
                        end if;

                        num_s       <= num_s(num_s'left-1 downto 0) & '0';
                        if rem_v >= 0 then
                            rem_v   := rem_v - den_s;
                        else
                            rem_v   := rem_v + den_s;
                        end if;

                        if rem_v < 0 then     -- previous subtraction caused negative remainder
                            quot_s  <= quot_s(quot_s'left-1 downto 0) & '0';
                        else
                            quot_s  <= quot_s(quot_s'left-1 downto 0) & '1';
                        end if;
                        if div_ctr_s < wn+frc-1 then
                            div_ctr_s   <= div_ctr_s + 1;
                        else
                            stat_s      <= 2;
                        end if;
                    when 2 =>
                        quot_o          <= quot_s;
                        if rem_v < 0 then
                            rem_v       := rem_v + den_s;
                        end if;
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
