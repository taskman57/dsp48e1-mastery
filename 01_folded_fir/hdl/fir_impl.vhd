library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

use work.dsp_pkg.all;

entity fir_impl is
    Port ( 
        clk_i           : in STD_LOGIC;
        rst_i           : in STD_LOGIC;
        data_i          : in STD_LOGIC_VECTOR (ADC_BIT_RES_C-1 downto 0);
        coef_i          : in fir_coef_t;
        sfr_dat_o       : out STD_LOGIC_VECTOR(ADC_BIT_RES_C-1 downto 0);
        prod_res_o      : out STD_LOGIC_VECTOR(ADC_BIT_RES_C-1 downto 0);
        fir_vld_o       : out std_logic
    );
end fir_impl;

architecture Behavioral of fir_impl is

    attribute shreg_extract : string;
    attribute srl_style     : string;

    signal sfr_reg_s        : sfr_fir_t := (others => (others => '0'));
    attribute shreg_extract of sfr_reg_s    : signal is "yes";
    attribute srl_style     of sfr_reg_s    : signal is "srl";  -- no register before or after

    ---- DSP singls
    signal dsp_mode_s       : dsp_mode_t    := (others => (others => '0'));
    signal alu_mod_s        : std_logic_vector(3 downto 0):= (others => '0');
    signal A_D_mod_s        : std_logic_vector(4 downto 0):= (others => '0');

    signal dsp_ainp_s       : ainp_t    := (others => (others => '0'));
    signal dsp_binp_s       : binp_t    := (others => (others => '0'));
    signal dsp_pcin_s       : pcin_t    := (others => (others => '0'));
    signal prod_res_s       : pcin_t    := (others => (others => '0'));
    signal dsp_dinp_s       : dinp_t    := (others => (others => '0'));

begin

    SFR_TAP_CTRL_PROC: process(clk_i)
        variable dly_ctr_v      : integer := 0;
    begin
        if rising_edge(clk_i) then
            if rst_i = '1' then
                sfr_reg_s           <= (others => (others => '0'));
                dly_ctr_v           := 0;
                fir_vld_o           <= '0';
            else
                -- input data shifting
                sfr_reg_s       <= sfr_reg_s(FIR_LEN_C-3 downto 0) & signed(data_i);

                if dly_ctr_v < (FIR_LEN_C/2 + DSP_LATANCY_C) - 1 then
                    dly_ctr_v   := dly_ctr_v + 1;
                else
                    fir_vld_o   <= '1';
                end if;

            end if;
        end if;
    end process;

    alu_mod_s   <= x"0";                    -- refere to pg.35 of DSP48E1, ALUMODE
    A_D_mod_s   <= '0' & x"5";              -- B2, refere to pg.31, pg.32 of DSP48E1, INMODE

    DSP_FILT_GEN:
    for dsp_stg in 0 to FIR_LEN_C/2-1 generate
    begin
        DSP0_IF:
        if dsp_stg = 0  generate
            dsp_ainp_s(dsp_stg)     <= std_logic_vector(resize(signed(data_i),DSP_AINP_LEN_C));
            dsp_pcin_s(dsp_stg)     <= (others => '0');
            dsp_mode_s(dsp_stg)     <= "000" & "01" & "01";     -- Z:0, X&Y: M, refere to pg.34 of DSP48E1
        end generate;

        DSPi_IF:
        if dsp_stg > 0  generate
            -- Rule 2: A-port taps advance by 2 (2*dsp_stg - 1)
            dsp_ainp_s(dsp_stg)     <= std_logic_vector(resize(signed(sfr_reg_s(2*dsp_stg-1)),DSP_AINP_LEN_C));
            dsp_pcin_s(dsp_stg)     <= prod_res_s(dsp_stg-1);
            dsp_mode_s(dsp_stg)     <= "001" & "01" & "01";     -- Z:PCIN, X&Y: M, refere to pg.34 of DSP48E1
        end generate;

        dsp_binp_s(dsp_stg)     <= std_logic_vector(resize(coef_i(dsp_stg),DSP_BINP_LEN_C));

        -- Rule 1: Every stage uses the exact same D-port tap (FIR_LEN_C-2)
        dsp_dinp_s(dsp_stg)     <= std_logic_vector(resize(sfr_reg_s(FIR_LEN_C-2),DSP_DINP_LEN_C));

        DSP48E1_inst : DSP48E1
        generic map (
            -- Feature Control Attributes: Data Path Selection
            A_INPUT => "DIRECT",                  -- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
            B_INPUT => "DIRECT",                  -- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
            USE_DPORT => TRUE,                   -- Select D port usage (TRUE or FALSE)
            USE_MULT => "MULTIPLY",               -- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
            USE_SIMD => "ONE48",                  -- SIMD selection ("ONE48", "TWO24", "FOUR12")
            -- Pattern Detector Attributes: Pattern Detection Configuration
            AUTORESET_PATDET => "NO_RESET",       -- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH" 
            MASK => X"3fffffffffff",              -- 48-bit mask value for pattern detect (1=ignore)
            PATTERN => X"000000000000",           -- 48-bit pattern match for pattern detect
            SEL_MASK => "MASK",                   -- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2" 
            SEL_PATTERN => "PATTERN",             -- Select pattern value ("PATTERN" or "C")
            USE_PATTERN_DETECT => "NO_PATDET",    -- Enable pattern detect ("PATDET" or "NO_PATDET")
            -- Register Control Attributes: Pipeline Register Configuration
            ACASCREG => 1,                        -- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2)
            ADREG => 1,                           -- Number of pipeline stages for pre-adder (0 or 1)
            ALUMODEREG => 0,                      -- Number of pipeline stages for ALUMODE (0 or 1)
            AREG => 1,                            -- Number of pipeline stages for A (0, 1 or 2)
            BCASCREG => 1,                        -- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
            BREG => 2,                            -- Number of pipeline stages for B (0, 1 or 2)
            CARRYINREG => 0,                      -- Number of pipeline stages for CARRYIN (0 or 1)
            CARRYINSELREG => 0,                   -- Number of pipeline stages for CARRYINSEL (0 or 1)
            CREG => 1,                            -- Number of pipeline stages for C (0 or 1)
            DREG => 1,                            -- Number of pipeline stages for D (0 or 1)
            INMODEREG => 0,                       -- Number of pipeline stages for INMODE (0 or 1)
            MREG => 1,                            -- Number of multiplier pipeline stages (0 or 1)
            OPMODEREG => 0,                       -- Number of pipeline stages for OPMODE (0 or 1)
            PREG => 1                             -- Number of pipeline stages for P (0 or 1)
        )
        port map (
            -- Cascade: 30-bit (each) output: Cascade Ports
            ACOUT => open,                        -- 30-bit output: A port cascade output
            BCOUT => open,                        -- 18-bit output: B port cascade output
            CARRYCASCOUT => open,                 -- 1-bit output: Cascade carry output
            MULTSIGNOUT => open,                  -- 1-bit output: Multiplier sign cascade output
            PCOUT => prod_res_s(dsp_stg),         -- 48-bit output: Cascade output
            -- Control: 1-bit (each) output: Control Inputs/Status Bits
            OVERFLOW => open,                     -- 1-bit output: Overflow in add/acc output
            PATTERNBDETECT => open,               -- 1-bit output: Pattern bar detect output
            PATTERNDETECT => open,                -- 1-bit output: Pattern detect output
            UNDERFLOW => open,                    -- 1-bit output: Underflow in add/acc output
            -- Data: 4-bit (each) output: Data Ports
            CARRYOUT => open,                     -- 4-bit output: Carry output
            P => open,                            -- 48-bit output: Primary data output
            -- Cascade: 30-bit (each) input: Cascade Ports
            ACIN => (others => '0'),              -- 30-bit input: A cascade data input
            BCIN => (others => '0'),              -- 18-bit input: B cascade input
            CARRYCASCIN => '0',                   -- 1-bit input: Cascade carry input
            MULTSIGNIN => '0',                    -- 1-bit input: Multiplier sign input
            PCIN => dsp_pcin_s(dsp_stg),          -- 48-bit input: P cascade input
            -- Control: 4-bit (each) input: Control Inputs/Status Bits
            ALUMODE => alu_mod_s,                 -- 4-bit input: ALU control input
            CARRYINSEL => "000",                  -- 3-bit input: Carry select input
            CLK => clk_i,                         -- 1-bit input: Clock input
            INMODE => A_D_mod_s,                  -- 5-bit input: INMODE control input
            OPMODE => dsp_mode_s(dsp_stg),        -- 7-bit input: Operation mode input
            -- Data: 30-bit (each) input: Data Ports
            A => dsp_ainp_s(dsp_stg),             -- 30-bit input: A data input
            B => dsp_binp_s(dsp_stg),             -- 18-bit input: B data input
            C => (others => '0'),                 -- 48-bit input: C data input
            CARRYIN => '0',                       -- 1-bit input: Carry input signal
            D => dsp_dinp_s(dsp_stg),             -- 25-bit input: D data input
            -- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
            CEA1 => '1',                          -- 1-bit input: Clock enable input for 1st stage AREG
            CEA2 => '0',                          -- 1-bit input: Clock enable input for 2nd stage AREG
            CEAD => '1',                          -- 1-bit input: Clock enable input for ADREG
            CEALUMODE => '1',                     -- 1-bit input: Clock enable input for ALUMODE
            CEB1 => '1',                          -- 1-bit input: Clock enable input for 1st stage BREG
            CEB2 => '1',                          -- 1-bit input: Clock enable input for 2nd stage BREG
            CEC => '1',                           -- 1-bit input: Clock enable input for CREG
            CECARRYIN => '0',                     -- 1-bit input: Clock enable input for CARRYINREG
            CECTRL => '0',                        -- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
            CED => '1',                           -- 1-bit input: Clock enable input for DREG
            CEINMODE => '1',                      -- 1-bit input: Clock enable input for INMODEREG
            CEM => '1',                           -- 1-bit input: Clock enable input for MREG
            CEP => '1',                           -- 1-bit input: Clock enable input for PREG
            RSTA => rst_i,                        -- 1-bit input: Reset input for AREG
            RSTALLCARRYIN => rst_i,               -- 1-bit input: Reset input for CARRYINREG
            RSTALUMODE => rst_i,                  -- 1-bit input: Reset input for ALUMODEREG
            RSTB => rst_i,                        -- 1-bit input: Reset input for BREG
            RSTC => rst_i,                        -- 1-bit input: Reset input for CREG
            RSTCTRL => rst_i,                     -- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
            RSTD => rst_i,                        -- 1-bit input: Reset input for DREG and ADREG
            RSTINMODE => rst_i,                   -- 1-bit input: Reset input for INMODEREG
            RSTM => rst_i,                        -- 1-bit input: Reset input for MREG
            RSTP => rst_i                         -- 1-bit input: Reset input for PREG
        );
    end generate;
    prod_res_o      <= prod_res_s(FIR_LEN_C/2-1)(31 downto 16);     -- obtianed from simulation

    sfr_dat_o       <= std_logic_vector(sfr_reg_s(FIR_LEN_C-2));

end Behavioral;
