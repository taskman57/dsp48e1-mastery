----------------------------------------------------------------------
-- tb_div_sweep.vhd
--
-- Runs tb_div_seq_full once for every (wn, wd, frc) set in
-- the table CFGS_C below, all in one simulation. Each instance runs the
-- six test scenarios on its own divider. At the end a table with the
-- result of every set is printed, then SWEEP PASSED or SWEEP FAILED.
--
-- To try another set, add a row to CFGS_C. The table can have any
-- number of rows.
--
-- Generics:
--   NUM_TESTS_G  number of random vectors per set (stage 6)
--   VERBOSE_G    true prints every PASS line and stage summary
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

entity tb_div_sweep is
    generic(
        NUM_TESTS_G : integer := 1000;
        VERBOSE_G   : boolean := false
    );
end entity;

architecture sim of tb_div_sweep is

    constant DUT_G      : integer := 1;     -- module number under test in full testbench
    type cfg_t is record
        wn  : integer;
        wd  : integer;
        frc : integer;
    end record;

    type cfg_array_t is array(natural range <>) of cfg_t;

    ----------------------------------------------------------------
    -- Table of (wn, wd, frc) sets. Add or change rows here.
    ----------------------------------------------------------------
    constant CFGS_C : cfg_array_t :=
    (
        (34, 10, 4),    -- the divider of the project
        (57, 51, 4),    -- in the range of int64
        (34, 10, 0),    -- no fractional bits
        (16,  6, 4),
        ( 5,  3, 3),    -- the default generics of the divider
        ( 6,  4, 0),
        ( 6,  4, 3),
        ( 4,  6, 0),    -- divisor wider than the dividend
        (60, 62, 0),    -- divisor wider than the dividend
        (50, 58, 6),    -- divisor wider than the dividend
        (32, 36, 1),    -- divisor wider than the dividend
        ( 4,  5, 3),
        ( 4,  2, 6),    -- more fractional bits than divisor bits
        (44, 32,16),    -- more fractional bits than divisor bits
        (40, 12,20),    -- more fractional bits than divisor bits
        ( 2,  3, 1),
        ( 1,  1, 0),    -- smallest case
        ( 8,  8, 8)
    );

    constant N_C : natural := CFGS_C'length;

    type int_array_t is array(0 to N_C-1) of integer;

    signal done_s       : std_logic_vector(0 to N_C-1);
    signal pass_s       : int_array_t;
    signal fail_s       : int_array_t;

    constant ALL_DONE_C : std_logic_vector(0 to N_C-1) := (others => '1');

begin

    ----------------------------------------------------------------
    -- One testbench instance per row of the table
    ----------------------------------------------------------------
    gen : for i in 0 to N_C-1 generate
        tb : entity work.tb_div_seq_full
            generic map (
                wn          => CFGS_C(CFGS_C'low + i).wn,
                wd          => CFGS_C(CFGS_C'low + i).wd,
                frc         => CFGS_C(CFGS_C'low + i).frc,
                NUM_TESTS_G => NUM_TESTS_G,
                VERBOSE_G   => VERBOSE_G,
                DUT_G       => DUT_G
            )
            port map (
                done_o      => done_s(i),
                pass_o      => pass_s(i),
                fail_o      => fail_s(i)
            );
    end generate;

    ----------------------------------------------------------------
    -- Result table
    ----------------------------------------------------------------
    summary_proc : process
        variable failed_sets_v : integer := 0;
        variable idx_v         : integer;
    begin
        wait until done_s = ALL_DONE_C;
        wait for 1 ns;

        report "=========== SWEEP RESULT ===========" severity note;

        for i in 0 to N_C-1 loop
            idx_v := CFGS_C'low + i;
            if fail_s(i) = 0 then
                report "wn=" & integer'image(CFGS_C(idx_v).wn)
                     & "  wd=" & integer'image(CFGS_C(idx_v).wd)
                     & "  frc=" & integer'image(CFGS_C(idx_v).frc)
                     & "  : PASSED (" & integer'image(pass_s(i)) & " tests)"
                     severity note;
            else
                failed_sets_v := failed_sets_v + 1;
                report "wn=" & integer'image(CFGS_C(idx_v).wn)
                     & "  wd=" & integer'image(CFGS_C(idx_v).wd)
                     & "  frc=" & integer'image(CFGS_C(idx_v).frc)
                     & "  : FAILED (" & integer'image(fail_s(i)) & " failures)"
                     severity error;
            end if;
        end loop;

        if failed_sets_v = 0 then
            report "DUT_G: " & integer'image(DUT_G) & " SWEEP PASSED: all " & integer'image(N_C) & " sets" severity note;
        else
            report "DUT_G: " & integer'image(DUT_G) & " SWEEP FAILED: " & integer'image(failed_sets_v) & " of "
                 & integer'image(N_C) & " sets" severity error;
        end if;

        report "====================================" severity note;
        wait;
    end process;

end architecture;
