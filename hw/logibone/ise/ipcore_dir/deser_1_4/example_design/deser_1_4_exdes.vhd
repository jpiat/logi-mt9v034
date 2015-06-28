-- file: deser_1_4_exdes.vhd
-- (c) Copyright 2009 - 2011 Xilinx, Inc. All rights reserved.
-- 
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
-- 
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
-- 
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
-- 
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES.

------------------------------------------------------------------------------
-- SelectIO wizard example design
------------------------------------------------------------------------------
-- This example design instantiates the IO circuitry
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.and_reduce;

library unisim;
use unisim.vcomponents.all;

entity deser_1_4_exdes is
generic (
  -- width of the data for the system
  sys_w      : integer := 1;
  -- width of the data for the device
  dev_w      : integer := 4
);
port (
  PATTERN_COMPLETED_OUT     : out   std_logic_vector (1 downto 0);
  -- From the system into the device
  DATA_IN_FROM_PINS_P      : in    std_logic_vector(sys_w-1 downto 0);
  DATA_IN_FROM_PINS_N      : in    std_logic_vector(sys_w-1 downto 0);
  DATA_OUT_TO_PINS_P         : out   std_logic_vector(sys_w-1 downto 0);
  DATA_OUT_TO_PINS_N         : out   std_logic_vector(sys_w-1 downto 0);
  CLK_TO_PINS_FWD_P         : out std_logic;
  CLK_TO_PINS_FWD_N         : out std_logic;

  CLK_IN_P                 : in    std_logic;
  CLK_IN_N                 : in    std_logic;
  CLK_IN_FWD_P             : in    std_logic;
  CLK_IN_FWD_N             : in    std_logic;
  CLK_RESET                : in    std_logic;
  IO_RESET                 : in    std_logic);
end deser_1_4_exdes;

architecture xilinx of deser_1_4_exdes is

component deser_1_4 is
generic
 (-- width of the data for the system
  sys_w       : integer := 1;
  -- width of the data for the device
  dev_w       : integer := 4);
port
 (
  -- From the system into the device
  DATA_IN_FROM_PINS_P     : in    std_logic_vector(sys_w-1 downto 0);
  DATA_IN_FROM_PINS_N     : in    std_logic_vector(sys_w-1 downto 0);
  DATA_IN_TO_DEVICE       : out   std_logic_vector(dev_w-1 downto 0);

-- Clock and reset signals
  CLK_IN_P                : in    std_logic;                    -- Differential fast clock from IOB
  CLK_IN_N                : in    std_logic;
  CLK_DIV_OUT             : out   std_logic;                    -- Slow clock output
  CLK_RESET               : in    std_logic;                    -- Reset signal for Clock circuit
  IO_RESET                : in    std_logic);                   -- Reset signal for IO circuit
end component;

   constant num_serial_bits  : integer := dev_w/sys_w;
   signal unused             : std_logic;
   signal clkin1             : std_logic;
   signal count_out          : std_logic_vector (num_serial_bits-1 downto 0);
   signal local_counter      : std_logic_vector(num_serial_bits-1 downto 0);
   signal pattern_completed    : std_logic_vector (1 downto 0) := "00";
   signal clk_in_int_inv       : std_logic;
   signal clk_in_int_inv_c     : std_logic;
   signal clk_div_int               : std_logic;
   signal clk_in_int_buf            : std_logic;
            -- connection between ram and io circuit
   signal data_in_to_device         : std_logic_vector(dev_w-1 downto 0);
   signal data_in_to_device_int2    : std_logic_vector(dev_w-1 downto 0);
   signal data_in_to_device_int3    : std_logic_vector(dev_w-1 downto 0);

   signal data_out_from_device : std_logic_vector(dev_w-1 downto 0);

    type serdarr is array (0 to 7) of std_logic_vector(sys_w-1 downto 0);
   signal oserdes_d                : serdarr := (( others => (others => '0')));
   signal ocascade_ms_d            : std_logic_vector(sys_w-1 downto 0);
   signal ocascade_ms_t            : std_logic_vector(sys_w-1 downto 0);
   signal ocascade_sm_d            : std_logic_vector(sys_w-1 downto 0);
   signal ocascade_sm_t            : std_logic_vector(sys_w-1 downto 0);
   signal serdesstrobe             : std_logic;

   signal data_out_from_device_q    : std_logic_vector(dev_w-1 downto 0) ;
   signal data_out_to_pins_int      : std_logic_vector(sys_w-1 downto 0);
   signal data_out_to_pins_predelay : std_logic_vector(sys_w-1 downto 0);
   constant clock_enable            : std_logic := '1';

   signal clk_div_out          : std_logic;
   signal clkfbout             : std_logic;
   signal clkfbout_buf         : std_logic;
   signal clk_in_pll           : std_logic;
   signal clk_in_pll1          : std_logic;
   signal locked_in            : std_logic;
   signal locked_out           : std_logic;
   signal clk_div_in_int       : std_logic;
   signal clk_div_in           : std_logic;
   signal clk_fwd_out          : std_logic;
   signal clk_fwd_int          : std_logic;
   signal clk_fwd_int_buf      : std_logic;
   signal serdesstrobe1        : std_logic;
   signal clk_in_int_buf_fwd   : std_logic;
   signal clk_div_fwd_int      : std_logic;
   signal clk_div_fwd          : std_logic;
   signal rst_sync      : std_logic;
   signal rst_sync_int  : std_logic;
   signal rst_sync_int1 : std_logic;
   signal rst_sync_int2 : std_logic;
   signal rst_sync_int3 : std_logic;
   signal rst_sync_int4 : std_logic;
   signal rst_sync_int5 : std_logic;
   signal rst_sync_int6 : std_logic;
   signal rst_sync_d      : std_logic;
   signal rst_sync_int_d  : std_logic;
   signal rst_sync_int1_d : std_logic;
   signal rst_sync_int2_d : std_logic;
   signal rst_sync_int3_d : std_logic;
   signal rst_sync_int4_d : std_logic;
   signal rst_sync_int5_d : std_logic;
   signal rst_sync_int6_d : std_logic;
begin

   process (clk_div_out, IO_RESET) begin
     if (IO_RESET = '1') then
       rst_sync <= '1';
       rst_sync_int <= '1';
       rst_sync_int1 <= '1';
       rst_sync_int2 <= '1';
       rst_sync_int3 <= '1';
       rst_sync_int4 <= '1';
       rst_sync_int5 <= '1';
       rst_sync_int6 <= '1';
     elsif (clk_div_out = '1' and clk_div_out'event) then
       rst_sync <= '0';
       rst_sync_int <= rst_sync;
       rst_sync_int1 <= rst_sync_int;
       rst_sync_int2 <= rst_sync_int1;
       rst_sync_int3 <= rst_sync_int2;
       rst_sync_int4 <= rst_sync_int3;
       rst_sync_int5 <= rst_sync_int4;
       rst_sync_int6 <= rst_sync_int5;
     end if;
   end process;

   process (clk_div_in, IO_RESET) begin
     if (IO_RESET = '1') then
       rst_sync_d <= '1';
       rst_sync_int_d <= '1';
       rst_sync_int1_d <= '1';
       rst_sync_int2_d <= '1';
       rst_sync_int3_d <= '1';
       rst_sync_int4_d <= '1';
       rst_sync_int5_d <= '1';
       rst_sync_int6_d <= '1';
     elsif (clk_div_in = '1' and clk_div_in'event) then
       rst_sync_d <= '0';
       rst_sync_int_d <= rst_sync_d;
       rst_sync_int1_d <= rst_sync_int_d;
       rst_sync_int2_d <= rst_sync_int1_d;
       rst_sync_int3_d <= rst_sync_int2_d;
       rst_sync_int4_d <= rst_sync_int3_d;
       rst_sync_int5_d <= rst_sync_int4_d;
       rst_sync_int6_d <= rst_sync_int5_d;
     end if;
   end process;


   clkin_in_buf : IBUFGDS
   port map
     (O  => clkin1,
      I  => CLK_IN_P,
      IB => CLK_IN_N);

   -- set up the fabric PLL_BASE to drive the BUFPLL
   pll_base_inst : PLL_BASE
    generic map (
      BANDWIDTH             => "OPTIMIZED",
      CLK_FEEDBACK          => "CLKFBOUT",
      COMPENSATION          => "SYSTEM_SYNCHRONOUS",
      DIVCLK_DIVIDE         => 1,
      CLKFBOUT_MULT         => 4,
      CLKFBOUT_PHASE        => 0.000,
      CLKOUT0_DIVIDE        => 4,
      CLKOUT0_PHASE         => 0.000,
      CLKOUT0_DUTY_CYCLE    => 0.500,
      CLKOUT1_DIVIDE        => 2,
      CLKOUT1_PHASE         => 0.000,
      CLKOUT1_DUTY_CYCLE    => 0.500,
      CLKOUT2_DIVIDE        => 4*num_serial_bits,
      CLKOUT2_PHASE         => 0.000,
      CLKOUT2_DUTY_CYCLE    => 0.500,
      CLKOUT3_DIVIDE        => 4,
      CLKOUT3_PHASE         => 0.000,
      CLKOUT3_DUTY_CYCLE    => 0.500,
      CLKIN_PERIOD          => 10.0,
      REF_JITTER            => 0.010)
   port map (
     -- Output clocks
      CLKFBOUT              => clkfbout,
      CLKOUT0               => clk_in_pll1,
      CLKOUT1               => clk_fwd_int,
      CLKOUT2               => clk_div_in_int,
      CLKOUT3               => clk_div_fwd_int,
      CLKOUT4               => open,
      CLKOUT5               => open,
      -- Status and control signals
      LOCKED                => locked_in,
      RST                   => CLK_RESET,
      -- Input clock control
      CLKFBIN               => clkfbout_buf,
      CLKIN                 => clkin1);

   clkfb_buf : BUFG
    port map (
      O            => clkfbout_buf,
      I            => clkfbout);

   clkd_buf : BUFG
    port map (
      O            => clk_div_in,
      I            => clk_div_in_int);

   clk_fwd_buf : BUFG
    port map (
      O            => clk_div_fwd,
      I            => clk_div_fwd_int);

   clko_buf : BUFG
    port map (
      O            => clk_in_pll,
      I            => clk_in_pll1);




   process(clk_div_in) begin
   if (clk_div_in='1' and clk_div_in'event) then
     if (rst_sync_int6_d = '1') then
       count_out <= (others => '0');
     elsif locked_in='1' then  
     count_out <= count_out + 1;
    end if;
   end if;
  end process;


   


assign:for assg in 0 to num_serial_bits-1 generate begin
pinsss:for pinsss in 0 to sys_w-1 generate begin
   data_out_from_device(pinsss+sys_w*assg) <= count_out(assg);
end generate pinsss;
end generate assign;


   process(clk_div_out) begin
   if (clk_div_out='1' and clk_div_out'event) then
   if (rst_sync_int6 = '1') then
       pattern_completed <= "00";
   elsif (and_reduce(data_in_to_device_int3) = '1') then
     pattern_completed <= "11";
   else
     pattern_completed <= "00";
   end if;
   end if;
 end process;

   process(clk_div_out) begin
   if (clk_div_out='1' and clk_div_out'event) then
   if (rst_sync_int6 = '1') then
        data_in_to_device_int2 <= (others => '0');
        data_in_to_device_int3 <= (others => '0');
     else
        data_in_to_device_int2 <= data_in_to_device;
        data_in_to_device_int3 <= data_in_to_device_int2;
     end if;

   end if;
 end process;




 
   PATTERN_COMPLETED_OUT <= pattern_completed;
  


   bufpll_inst : BUFPLL
    generic map (
      DIVIDE        => 4)
    port map (
      IOCLK        => clk_in_int_buf,
      LOCK         => locked_out,
      SERDESSTROBE => serdesstrobe,
      GCLK         => clk_div_in,  -- GCLK pin must be driven by BUFG
      LOCKED       => locked_in,
      PLLIN        => clk_in_pll1);





  pins: for pin_count in 0 to sys_w-1 generate
    -- Instantiate the buffers
    ----------------------------------
     obufds_inst : OBUFDS
       generic map (
         IOSTANDARD => "LVDS_33")
       port map (
         O          => DATA_OUT_TO_PINS_P  (pin_count),
         OB         => DATA_OUT_TO_PINS_N  (pin_count),
         I          => data_out_to_pins_predelay(pin_count));

     -- Instantiate the serdes primitive
     ----------------------------------
     -- declare the oserdes
     oserdes2_master : OSERDES2
       generic map (
         DATA_RATE_OQ   => "SDR",
         DATA_RATE_OT   => "SDR",
         TRAIN_PATTERN  => 0,
         DATA_WIDTH     => 4,
         SERDES_MODE    => "NONE",
         OUTPUT_MODE    => "SINGLE_ENDED")
       port map (
        D1         => oserdes_d(3)(pin_count),
        D2         => oserdes_d(2)(pin_count),
        D3         => oserdes_d(1)(pin_count),
        D4         => oserdes_d(0)(pin_count),
        T1         => '0',
        T2         => '0',
        T3         => '0',
        T4         => '0',
        SHIFTIN1   => '1',
        SHIFTIN2   => '1',
        SHIFTIN3   => '1',
        SHIFTIN4   => '1',
        SHIFTOUT1  => open,
        SHIFTOUT2  => open,
        SHIFTOUT3  => open,
        SHIFTOUT4  => open,
        TRAIN      => '0',
        OCE        => clock_enable,
        CLK0       => clk_in_int_buf,
        CLK1       => '0',
        CLKDIV     => clk_div_in,
        OQ         => data_out_to_pins_predelay(pin_count),
        TQ         => open,
        IOCE       => serdesstrobe,
        TCE        => clock_enable,
        RST        => IO_RESET);





     -- Concatenate the serdes outputs together. Keep the timesliced
     --   bits together, and placing the earliest bits on the right
     --   ie, if data comes in 0, 1, 2, 3, 4, 5, 6, 7, ...
     --       the output will be 3210, 7654, ...
     -------------------------------------------------------------
    out_slices: for slice_count in 0 to num_serial_bits-1 generate begin
        -- This places the first data in time on the right
        oserdes_d(4-slice_count-1)(0) <=
           data_out_from_device(slice_count);
        -- To place the first data in time on the left, use the
        --   following code, instead
        -- oserdes_d(slice_count) <=
        --    data_out_from_device(slice_count);
     end generate out_slices;
  end generate pins;

  bufpll_inst_fwd : BUFPLL
     generic map (
       DIVIDE        => 2)
     port map (
       IOCLK        => clk_in_int_buf_fwd,
       LOCK         => locked_out,
       SERDESSTROBE => serdesstrobe1,
       GCLK         => clk_div_fwd,
       LOCKED       => locked_in,
       PLLIN        => clk_fwd_int);

     oserdes2_fwd : OSERDES2
     generic map (
         DATA_RATE_OQ   => "SDR",
         DATA_RATE_OT   => "SDR",
	 TRAIN_PATTERN  => 0,
         DATA_WIDTH     => 4,	
         SERDES_MODE    => "NONE",
	 OUTPUT_MODE    => "SINGLE_ENDED")
     port map (
         D1             => '1',
         D2             => '0',
         D3             => '1',
         D4             => '0',
         T1             => '0',
         T2             => '0',
         T3             => '0',
         T4             => '0',
         SHIFTIN1       => '1',
         SHIFTIN2       => '1',
         SHIFTIN3       => '1',
         SHIFTIN4       => '1',
         SHIFTOUT1      => open,
         SHIFTOUT2      => open,
         SHIFTOUT3      => open,
         SHIFTOUT4      => open,
	 TRAIN          => '0',
	 OCE		=> locked_in,
	 CLK0		=> clk_in_int_buf_fwd,
	 CLK1		=> '0',
	 CLKDIV		=> clk_div_fwd,
 	 OQ		=> clk_fwd_out,
         TQ		=> open,
	 IOCE		=> serdesstrobe1,
	 TCE		=> clock_enable,
         RST            => IO_RESET);

          obufds_clk_inst : OBUFDS
           generic map (
             IOSTANDARD => "LVDS_33")
           port map (
             O          => CLK_TO_PINS_FWD_P,
             OB         => CLK_TO_PINS_FWD_N,
             I          => clk_fwd_out);

   -- Instantiate the IO design
   io_inst : deser_1_4
   port map
   (
    -- From the system into the device
    DATA_IN_FROM_PINS_P     => DATA_IN_FROM_PINS_P,
    DATA_IN_FROM_PINS_N     => DATA_IN_FROM_PINS_N,
    DATA_IN_TO_DEVICE       => data_in_to_device,


    CLK_IN_P                => CLK_IN_FWD_P,
    CLK_IN_N                => CLK_IN_FWD_N,
    CLK_DIV_OUT             => clk_div_out,
    CLK_RESET               => CLK_RESET,
    IO_RESET                => rst_sync_int);
end xilinx;
