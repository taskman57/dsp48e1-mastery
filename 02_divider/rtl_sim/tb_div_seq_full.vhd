----------------------------------------------------------------------
-- tb_div_seq_full.vhd
--
-- Monolithic testbench for div_seq_restoring (generics wn, wd, frc).
-- It merges the six testbenches of the sequential divider project, in
-- the order of the project README:
--
--   1. Reference-model verification   (tb_divider_refmodel)
--   2. Mini scoreboard                (tb_divider_mini_scoreboard)
--   3. Corner cases                   (tb_divider_corner_cases)
--   4. Robustness                     (tb_divider_robustnes)
--   5. Divide-by-zero                 (tb_divider_divbyzero)
--   6. Randomized reference model     (tb_divider_random)
--
-- Adaptations for the new divider, no change in test structure:
--   * all widths come from the generics wn, wd and frc
--   * the expected quotient is floor(num * 2**frc / den), and the
--     expected remainder is num * 2**frc - quotient * den
--   * the reference works on unsigned vectors, so wide configurations
--     such as (34, 10, 4) do not overflow VHDL integers
--   * operands written as small integers (100, 255, ...) are clipped to
--     wn / wd bits. A non-zero divisor that clips to zero becomes 1.
--     The expected values always come from the operands that are applied
--   * check_result also checks the remainder and err_o
--   * an oversized-quotient skip is not needed: with den >= 1 the
--     quotient always fits in wn + frc bits
--   * a timeout on the ready wait, per-stage and total summaries
--   * stages 1 and 2 have 7 tests each (the first 3 are the originals)
--   * VERBOSE_G = false hides the PASS lines and the stage summaries.
--   * DUT_G selects the divider under test: 0 = div_seq_restoring,
--     1 = div_seq_nonrestoring, 2 = div_seq_nonrestoring2. To add another
--     divider, copy one generate block, change the entity name and give
--     it the next number. All the files must be analyzed together.
--     The ports done_o, pass_o and fail_o let tb_div_sweep.vhd run
--     several (wn, wd, frc) sets in one simulation. When this file is
--     the top level, leave the ports unconnected.
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.uniform;

entity tb_div_seq_full is
    generic(
        wn          : integer := 34;
        wd          : integer := 10;
        frc         : integer := 4;
        NUM_TESTS_G : integer := 100;
        VERBOSE_G   : boolean := true;
        DUT_G       : integer := 0     -- selects the divider, see the generate blocks
    );
    port(
        done_o      : out std_logic := '0';
        pass_o      : out integer   := 0;
        fail_o      : out integer   := 0
    );
end entity;

architecture sim of tb_div_seq_full is

    ----------------------------------------------------------------
    -- Constants derived from the generics
    ----------------------------------------------------------------
    function max_nat(a, b : natural) return natural is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function;

    function min_nat(a, b : natural) return natural is
    begin
        if a < b then
            return a;
        else
            return b;
        end if;
    end function;

    constant CLK_PERIOD_C   : time    := 10 ns;
    constant QW_C           : natural := wn + frc;              -- quotient width
    constant RW_C           : natural := max_nat(wn + frc, wd); -- reference width
    constant TIMEOUT_C      : time    := (4 * (wn + frc) + 20) * CLK_PERIOD_C;
    constant RST_DLY_C      : natural := min_nat(5, wn + frc);  -- clocks before reset in stage 4
    constant TAG_C          : string  := "[wn=" & integer'image(wn)
                                       & " wd=" & integer'image(wd)
                                       & " frc=" & integer'image(frc) & "] ";

    ----------------------------------------------------------------
    -- DUT signals
    ----------------------------------------------------------------
    signal clk_i    : std_logic := '0';
    signal rst_i    : std_logic := '1';
    signal ena_i    : std_logic := '0';

    signal num_i    : std_logic_vector(wn-1 downto 0) := (others => '0');
    signal den_i    : std_logic_vector(wd-1 downto 0) := (others => '0');

    signal busy_o   : std_logic;
    signal rdy_o    : std_logic;
    signal err_o    : std_logic;
    signal quot_o   : std_logic_vector(wn+frc-1 downto 0);
    signal rem_o    : std_logic_vector(wd-1 downto 0);

    signal done_s   : std_logic := '0';

    ----------------------------------------------------------------
    -- Helper functions
    ----------------------------------------------------------------
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

    -- Dividend operand from a small integer, clipped to wn bits
    function num_c(v : natural) return unsigned is
    begin
        return resize(to_unsigned(v, 32), wn);
    end function;

    -- Divisor operand from a small integer, clipped to wd bits.
    -- A non-zero value never clips to zero.
    function den_c(v : natural) return unsigned is
        variable r : unsigned(wd-1 downto 0);
    begin
        r := resize(to_unsigned(v, 32), wd);
        if (v /= 0) and (r = 0) then
            r := to_unsigned(1, wd);
        end if;
        return r;
    end function;

    -- Wide operands: num_c and den_c take a VHDL integer, so they stop
    -- at 31 bits. For directed values wider than that, write a hex
    -- literal and use num_u / den_u. They clip or extend to wn / wd bits
    -- in the same way. Example: num_u(x"2A5A5A5A5A5") is a 42-bit value.
    function num_u(v : unsigned) return unsigned is
    begin
        return resize(v, wn);
    end function;

    function den_u(v : unsigned) return unsigned is
        variable r : unsigned(wd-1 downto 0);
    begin
        r := resize(v, wd);
        if (v /= 0) and (r = 0) then
            r := to_unsigned(1, wd);
        end if;
        return r;
    end function;

    -- Reference model: floor(n * 2**frc / d), d must not be zero
    function ref_quot(n : unsigned; d : unsigned) return unsigned is
        variable nn : unsigned(RW_C-1 downto 0);
        variable dd : unsigned(RW_C-1 downto 0);
        variable qq : unsigned(RW_C-1 downto 0);
    begin
        nn := shift_left(resize(n, RW_C), frc);
        dd := resize(d, RW_C);
        qq := nn / dd;
        return resize(qq, QW_C);
    end function;

    -- Reference model: n * 2**frc - quotient * d, d must not be zero
    function ref_rem(n : unsigned; d : unsigned) return unsigned is
        variable nn : unsigned(RW_C-1 downto 0);
        variable dd : unsigned(RW_C-1 downto 0);
        variable rr : unsigned(RW_C-1 downto 0);
    begin
        nn := shift_left(resize(n, RW_C), frc);
        dd := resize(d, RW_C);
        rr := nn rem dd;
        return resize(rr, wd);
    end function;

    ----------------------------------------------------------------
    -- Checker procedures
    ----------------------------------------------------------------
    procedure check_result(
        constant test_name      : string;
        constant actual_q       : std_logic_vector;
        constant actual_r       : std_logic_vector;
        constant actual_err     : std_logic;
        constant expected_q     : unsigned;
        constant expected_r     : unsigned;
        variable pass_count_v   : inout integer;
        variable fail_count_v   : inout integer
    ) is
    begin

        if (unsigned(actual_q) = expected_q) and
           (unsigned(actual_r) = expected_r) and
           (actual_err = '0') then

            pass_count_v := pass_count_v + 1;

            if VERBOSE_G then
                report "PASS: "
                    & test_name
                    & " -> quotient = 0x"
                    & to_hex(actual_q)
                    & " remainder = 0x"
                    & to_hex(actual_r)
                    severity note;
            end if;

        else

            fail_count_v := fail_count_v + 1;

            report "FAIL: "
                & TAG_C
                & test_name
                & " expected quotient=0x"
                & to_hex(std_logic_vector(expected_q))
                & " remainder=0x"
                & to_hex(std_logic_vector(expected_r))
                & " actual quotient=0x"
                & to_hex(actual_q)
                & " remainder=0x"
                & to_hex(actual_r)
                & " err="
                & std_logic'image(actual_err)
                severity error;

        end if;

    end procedure;

    procedure check_div_error(
        constant test_name      : string;
        constant actual_q       : std_logic_vector;
        constant actual_r       : std_logic_vector;
        constant actual_error   : std_logic;
        variable pass_count_v   : inout integer;
        variable fail_count_v   : inout integer
    ) is
    begin
        if (unsigned(actual_q) = 0) and (unsigned(actual_r) = 0) and (actual_error = '1') then
            pass_count_v := pass_count_v + 1;
            if VERBOSE_G then
                report "PASS: "
                        & test_name
                        & " divide-by-zero handled -> quotient = 0x"
                        & to_hex(actual_q)
                        severity note;
            end if;
        else
            fail_count_v := fail_count_v + 1;
            report "FAIL: "
                    & TAG_C
                    & test_name
                    & " divide-by-zero handling incorrect -> quotient = 0x"
                    & to_hex(actual_q)
                    & " remainder = 0x"
                    & to_hex(actual_r)
                    & " err = "
                    & std_logic'image(actual_error)
                    severity error;
        end if;
    end procedure;

    procedure random_slv(
        variable seed1_v : inout positive;
        variable seed2_v : inout positive;
        constant width   : integer;
        variable result  : out std_logic_vector
    )
    is
        variable rand_v : real;
    begin

        for i in result'range loop

            uniform(seed1_v, seed2_v, rand_v);

            if rand_v < 0.5 then
                result(i) := '0';
            else
                result(i) := '1';
            end if;

        end loop;

    end procedure;

    ----------------------------------------------------------------
    -- Test vectors
    ----------------------------------------------------------------
    type test_vector_t is record
        dividend : unsigned(wn-1 downto 0);
        divisor  : unsigned(wd-1 downto 0);
    end record;

    type test_vector_array_t is array(natural range <>) of test_vector_t;

    constant MAX_NUM_C : unsigned(wn-1 downto 0) := (others => '1');
    constant MAX_DEN_C : unsigned(wd-1 downto 0) := (others => '1');

    -- Stage 1: reference-model verification (the first 3 are the originals)
    constant refmodel_vectors : test_vector_array_t :=
    (
        (num_c(100),  den_c(10)),
        (num_c(99),   den_c(3)),
        (num_c(200),  den_c(5)),

        -- Exact division, zero remainder.
        (num_c(255),  den_c(15)),

        -- Inexact division, non-zero remainder.
        (num_c(1000), den_c(7)),

        -- Dividend equal to the divisor: the quotient is exactly 1.
        (num_c(12),   den_c(12)),

        -- Dividend below the divisor: the quotient has fractional bits only.
        (num_c(5),    den_c(9))
    );

    -- Stage 2: mini scoreboard (the first 3 are the originals)
    constant scoreboard_vectors : test_vector_array_t :=
    (
        (num_c(100),  den_c(10)),
        (num_c(99),   den_c(3)),
        (num_c(200),  den_c(5)),

        -- Odd dividend over 2: the fractional part starts with a 1.
        (num_c(77),   den_c(2)),

        -- 1 / 3: a repeating binary fraction.
        (num_c(1),    den_c(3)),

        -- Power-of-two divisor: the division is a shift.
        (num_c(2047), den_c(64)),

        -- Dividend just above the divisor.
        (num_c(500),  den_c(499))
    );

    -- Stage 3: corner cases
    constant corner_vectors : test_vector_array_t :=
    (
        (num_c(100), den_c(10)),
        (num_c(99),  den_c(3)),
        (num_c(200), den_c(5)),
        (num_c(17),  den_c(4)),
        (num_c(255), den_c(16)),
        (num_c(31),  den_c(31)),
        (num_c(7),   den_c(31)),
        (num_c(0),   den_c(7)),
        (num_c(123), den_c(1)),

        -- Wide operands, above 32 bits. For narrow sets they are clipped.
        -- 42-bit dividend over a 38-bit divisor.
        (num_u(x"2A5A5A5A5A5"), den_u(x"2AAAAAAAAA")),

        -- 2**32 over 3: the first dividend that needs more than 32 bits.
        (num_u(x"100000000"), den_c(3)),

        -- 40-bit all ones over 32-bit all ones.
        (num_u(x"FFFFFFFFFF"), den_u(x"FFFFFFFF")),

        -- 40-bit dividend with a single bit set above bit 32, over a
        -- divisor wider than 32 bits: quotient close to 2**8.
        (num_u(x"A5F0F0F0F0"), den_u(x"0F0F0F0F1"))
    );

    -- Stage 4: robustness
    constant robust_vectors : test_vector_array_t :=
    (
        -- Smallest non-zero quotient.
        -- Verifies lower quotient boundary handling.
        (num_c(1), den_c(1)),

        -- Maximum supported divisor over itself.
        -- Verifies correct operation at the upper divisor boundary.
        (resize(MAX_DEN_C, wn), MAX_DEN_C),

        -- Dividend one count below the maximum divisor.
        -- Verifies the dividend < divisor boundary condition.
        (resize(MAX_DEN_C - 1, wn), MAX_DEN_C),

        -- Maximum dividend over 1: the largest quotient.
        -- Verifies quotient-width boundary handling (wn + frc bits).
        (MAX_NUM_C, den_c(1)),

        -- One count below the maximum dividend over 1.
        -- Verifies behavior immediately below the quotient limit.
        (MAX_NUM_C - 1, den_c(1))
    );

    -- Stage 5: divide by zero
    constant divzero_vectors : test_vector_array_t :=
    (
        -- Divide-by-zero with a non-zero dividend.
        -- Verifies error detection and handling for an invalid divisor.
        (num_c(100), den_c(0)),

        -- Divide-by-zero with a zero dividend.
        -- Verifies that the error condition is still detected when both
        -- operands are zero.
        (num_c(0), den_c(0)),

        -- Valid division after divide-by-zero transactions.
        -- Verifies DUT recovery and correct operation after an error event.
        (num_c(200), den_c(10))
    );

begin

    ----------------------------------------------------------------
    -- DUT
    ----------------------------------------------------------------
    dut_0 : if DUT_G = 0 generate
        dut : entity work.div_seq_restoring
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
    end generate;

    dut_1 : if DUT_G = 1 generate
        dut : entity work.div_seq_nonrestoring
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
    end generate;

    ----------------------------------------------------------------
    -- Clock generator (stops when the test is done)
    ----------------------------------------------------------------
    clk_process : process
    begin
        while done_s = '0' loop
            clk_i <= '0';
            wait for CLK_PERIOD_C / 2;
            clk_i <= '1';
            wait for CLK_PERIOD_C / 2;
        end loop;
        wait;
    end process;

    ----------------------------------------------------------------
    -- Stimulus process
    ----------------------------------------------------------------
    stim_proc : process

        variable pass_count_v   : integer := 0;
        variable fail_count_v   : integer := 0;
        variable total_pass_v   : integer := 0;
        variable total_fail_v   : integer := 0;
        variable old_fail_v     : integer := 0;

        variable expected_q_v   : unsigned(QW_C-1 downto 0);
        variable expected_r_v   : unsigned(wd-1 downto 0);

        variable seed1_v        : positive := 491236;
        variable seed2_v        : positive := 1163;
        variable rand_num_v     : std_logic_vector(num_i'range);
        variable rand_den_v     : std_logic_vector(den_i'range);

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
            constant n : in unsigned;
            constant d : in unsigned
        ) is
        begin
            num_i <= std_logic_vector(n);
            den_i <= std_logic_vector(d);

            wait until rising_edge(clk_i);
            ena_i <= '1';

            wait until rising_edge(clk_i);
            ena_i <= '0';
        end procedure;

        ----------------------------------------------------------------
        -- Wait for the ready pulse, with a timeout
        ----------------------------------------------------------------
        procedure wait_ready is
        begin
            wait until rdy_o = '1' for TIMEOUT_C;
            if rdy_o /= '1' then
                report "TIMEOUT: rdy_o did not assert" severity error;
            end if;
        end procedure;

        ----------------------------------------------------------------
        -- Per-stage summary, and accumulation into the totals
        ----------------------------------------------------------------
        procedure stage_summary(constant stage_name : string) is
        begin
            if VERBOSE_G or (fail_count_v /= 0) then
                report TAG_C & "Divider " & stage_name & " verification completed"
                    severity note;

                report "-----------------------------------"
                    severity note;

                report TAG_C & "SCOREBOARD SUMMARY (" & stage_name & ")"
                    severity note;

                report "PASS COUNT = "
                    & integer'image(pass_count_v)
                    severity note;

                report "FAIL COUNT = "
                    & integer'image(fail_count_v)
                    severity note;

                report "-----------------------------------"
                    severity note;
            end if;

            total_pass_v := total_pass_v + pass_count_v;
            total_fail_v := total_fail_v + fail_count_v;
            pass_count_v := 0;
            fail_count_v := 0;
        end procedure;

    begin

        if VERBOSE_G then
            report "Generics: wn = " & integer'image(wn)
                & ", wd = " & integer'image(wd)
                & ", frc = " & integer'image(frc)
                severity note;
        end if;

        ----------------------------------------------------------------
        -- Stage 1: reference-model verification
        ----------------------------------------------------------------
        do_reset;

        for i in refmodel_vectors'range loop

            start_division(refmodel_vectors(i).dividend, refmodel_vectors(i).divisor);
            wait_ready;

            expected_q_v := ref_quot(refmodel_vectors(i).dividend, refmodel_vectors(i).divisor);
            expected_r_v := ref_rem(refmodel_vectors(i).dividend, refmodel_vectors(i).divisor);

            assert (unsigned(quot_o) = expected_q_v) and (unsigned(rem_o) = expected_r_v)
                report "Mismatch " & TAG_C & "Test " & integer'image(i - refmodel_vectors'low + 1)
                severity error;
            if (unsigned(quot_o) = expected_q_v) and (unsigned(rem_o) = expected_r_v) then
                pass_count_v := pass_count_v + 1;
            else
                fail_count_v := fail_count_v + 1;
            end if;

        end loop;

        stage_summary("reference-model");

        ----------------------------------------------------------------
        -- Stage 2: mini scoreboard
        ----------------------------------------------------------------
        do_reset;

        for i in scoreboard_vectors'range loop

            start_division(scoreboard_vectors(i).dividend, scoreboard_vectors(i).divisor);
            wait_ready;

            expected_q_v := ref_quot(scoreboard_vectors(i).dividend, scoreboard_vectors(i).divisor);
            expected_r_v := ref_rem(scoreboard_vectors(i).dividend, scoreboard_vectors(i).divisor);

            check_result(
                "Test " & integer'image(i - scoreboard_vectors'low + 1),
                quot_o,
                rem_o,
                err_o,
                expected_q_v,
                expected_r_v,
                pass_count_v,
                fail_count_v
            );

        end loop;

        stage_summary("mini-scoreboard");

        ----------------------------------------------------------------
        -- Stage 3: corner cases
        ----------------------------------------------------------------
        do_reset;

        for i in corner_vectors'range loop

            start_division(corner_vectors(i).dividend, corner_vectors(i).divisor);
            wait_ready;

            expected_q_v := ref_quot(corner_vectors(i).dividend, corner_vectors(i).divisor);
            expected_r_v := ref_rem(corner_vectors(i).dividend, corner_vectors(i).divisor);

            check_result(
                "Test " & integer'image(i),
                quot_o,
                rem_o,
                err_o,
                expected_q_v,
                expected_r_v,
                pass_count_v,
                fail_count_v
            );

        end loop;

        stage_summary("corner-case");

        ----------------------------------------------------------------
        -- Stage 4: robustness
        ----------------------------------------------------------------
        do_reset;

        ---- Loop Test
        for i in robust_vectors'range loop

            start_division(robust_vectors(i).dividend, robust_vectors(i).divisor);
            wait_ready;

            expected_q_v := ref_quot(robust_vectors(i).dividend, robust_vectors(i).divisor);
            expected_r_v := ref_rem(robust_vectors(i).dividend, robust_vectors(i).divisor);

            check_result(
                "Test " & integer'image(i),
                quot_o,
                rem_o,
                err_o,
                expected_q_v,
                expected_r_v,
                pass_count_v,
                fail_count_v
            );
        end loop;

        ---- Applying reset assertion test
        num_i <= std_logic_vector(num_c(180));
        den_i <= std_logic_vector(den_c(14));
        wait until rising_edge(clk_i);
        ena_i <= '1';

        wait until rising_edge(clk_i);
        ena_i <= '0';

        for i in 1 to RST_DLY_C loop
            wait until rising_edge(clk_i);
        end loop;
        rst_i <= '1';
        wait until rising_edge(clk_i);
        rst_i <= '0';

        start_division(num_c(200), den_c(5));
        wait_ready;

        expected_q_v := ref_quot(num_c(200), den_c(5));
        expected_r_v := ref_rem(num_c(200), den_c(5));

        check_result(
            "Test Reset assertion ",
            quot_o,
            rem_o,
            err_o,
            expected_q_v,
            expected_r_v,
            pass_count_v,
            fail_count_v
        );

        stage_summary("robustness");

        ----------------------------------------------------------------
        -- Stage 5: divide by zero
        ----------------------------------------------------------------
        do_reset;

        for i in divzero_vectors'range loop

            start_division(divzero_vectors(i).dividend, divzero_vectors(i).divisor);
            wait_ready;

            if divzero_vectors(i).divisor /= 0 then
                expected_q_v := ref_quot(divzero_vectors(i).dividend, divzero_vectors(i).divisor);
                expected_r_v := ref_rem(divzero_vectors(i).dividend, divzero_vectors(i).divisor);
                check_result(
                    "Test " & integer'image(i),
                    quot_o,
                    rem_o,
                    err_o,
                    expected_q_v,
                    expected_r_v,
                    pass_count_v,
                    fail_count_v
                );
            else
                check_div_error(
                    "Test " & integer'image(i),
                    quot_o,
                    rem_o,
                    err_o,
                    pass_count_v,
                    fail_count_v
                );
            end if;
        end loop;

        stage_summary("divide-by-zero");

        ----------------------------------------------------------------
        -- Stage 6: randomized reference model
        ----------------------------------------------------------------
        do_reset;

        for i in 1 to NUM_TESTS_G loop

            random_slv(seed1_v, seed2_v, num_i'length, rand_num_v);
            random_slv(seed1_v, seed2_v, den_i'length, rand_den_v);

            old_fail_v := fail_count_v;

            start_division(unsigned(rand_num_v), unsigned(rand_den_v));
            wait_ready;

            if unsigned(rand_den_v) /= 0 then
                expected_q_v := ref_quot(unsigned(rand_num_v), unsigned(rand_den_v));
                expected_r_v := ref_rem(unsigned(rand_num_v), unsigned(rand_den_v));
                check_result(
                    "Test " & integer'image(i),
                    quot_o,
                    rem_o,
                    err_o,
                    expected_q_v,
                    expected_r_v,
                    pass_count_v,
                    fail_count_v
                );
            else
                check_div_error(
                    "Test " & integer'image(i),
                    quot_o,
                    rem_o,
                    err_o,
                    pass_count_v,
                    fail_count_v
                );
            end if;

            if old_fail_v /= fail_count_v then
                report " Num: "
                    & "0x"
                    & to_hex(rand_num_v)
                    severity note;
                report " Denum: "
                    & "0x"
                    & to_hex(rand_den_v)
                    severity note;
            end if;
        end loop;

        stage_summary("random");

        ----------------------------------------------------------------
        -- Finish simulation
        ----------------------------------------------------------------
        if VERBOSE_G then
            report "==================================="
                severity note;

            report "TOTAL PASS COUNT = "
                & integer'image(total_pass_v)
                severity note;

            report "TOTAL FAIL COUNT = "
                & integer'image(total_fail_v)
                severity note;
        end if;

        if total_fail_v = 0 then
            report TAG_C & "TESTBENCH PASSED (" & integer'image(total_pass_v) & " tests)"
                severity note;
        else
            report TAG_C & "TESTBENCH FAILED (" & integer'image(total_fail_v) & " failures)"
                severity error;
        end if;

        if VERBOSE_G then
            report "==================================="
                severity note;
        end if;

        pass_o <= total_pass_v;
        fail_o <= total_fail_v;
        done_o <= '1';
        done_s <= '1';
        wait;

    end process;

end architecture;
