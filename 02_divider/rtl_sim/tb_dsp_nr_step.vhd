library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_dsp_nr_step is
    generic(
        wn          : integer := 5;
        wd          : integer := 3;
        frc         : integer := 2
    );
end entity tb_dsp_nr_step;

architecture sim of tb_dsp_nr_step is

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal clk_i    : std_logic := '0';
    signal rst_i    : std_logic := '1';
    signal ena_i    : std_logic := '0';

    signal num_i    : std_logic_vector(wn-1 downto 0) := std_logic_vector(to_unsigned(6, wn));
    signal den_i    : std_logic_vector(wd-1 downto 0) := std_logic_vector(to_unsigned(3, wd));

    signal busy_o   : std_logic;
    signal rdy_o    : std_logic;
    signal err_o    : std_logic;
    signal quot_o   : std_logic_vector(wn+frc-1 downto 0);
    signal rem_o    : std_logic_vector(wd-1 downto 0);

    type simple_test_vector_t is record
        dividend : std_logic_vector(wn-1 downto 0);
        divisor  : std_logic_vector(wd-1 downto 0);
    end record;
    type test_vector_array_t is array(0 to 5) of simple_test_vector_t;
    signal refmodel_vectors : test_vector_array_t :=
    (
        ("01000", "100"),-- (08,4)
        ("01011", "101"),-- (11,5)
        ("00001", "001"),-- (01,1)
        ("01010", "011"),-- (10,3)
        ("00001", "100"),-- (10,4)
        ("11111", "111") -- (31,7)
    );

    constant CLK_PERIOD_C   : time    := 10 ns;

begin

        dut : entity work.dsp_nr_step
            generic map (
                wn      => wn,
                wd      => wd,
                frc     => frc
            )
            port map (
                clk_i   => clk_i,
                rst_i   => rst_i,
                ena_i   => ena_i,
                num_i   => num_i,
                den_i   => den_i,
                busy_o  => busy_o,
                rdy_o   => rdy_o,
                rem_o   => rem_o,
                quot_o  => quot_o,
                err_o   => err_o
            );
    ----------------------------------------------------------------
    -- Clock generator (stops when the test is done)
    ----------------------------------------------------------------
    clk_process : process
    begin
        clk_i <= '0';
        wait for CLK_PERIOD_C / 2;
        clk_i <= '1';
        wait for CLK_PERIOD_C / 2;
        -- wait;
    end process;

    stim_proc: process
        ----------------------------------------------------------------
        -- Reset phase
        ----------------------------------------------------------------
        procedure do_reset is
        begin
            rst_i <= '1';
            wait for 30 ns;
            wait until rising_edge(clk_i);  -- to prevent any edge simulation conflict between reset and clk_i
            rst_i <= '0';

            wait for 10 ns;
        end procedure;

        ----------------------------------------------------------------
        -- Apply the operands and give a one-clock start pulse
        ----------------------------------------------------------------
        procedure start_division(
            signal n : in std_logic_vector;
            signal d : in std_logic_vector)
        is
        begin
            num_i <= std_logic_vector(n);
            den_i <= std_logic_vector(d);

            wait until rising_edge(clk_i);
            ena_i <= '1';

            wait until rising_edge(clk_i);
            ena_i <= '0';
            wait until rdy_o = '1';
        end procedure;
    begin
        do_reset;
        for i in 0 to refmodel_vectors'length-1 loop
            start_division(refmodel_vectors(i).dividend, refmodel_vectors(i).divisor);
            report " Test DSP division: " & integer'image(i)
            severity note;
        end loop;
        wait;
    end process;

end architecture;