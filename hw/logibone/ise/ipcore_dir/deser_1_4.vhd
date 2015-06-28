-- file: deser_1_4.vhd
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
-- User entered comments
------------------------------------------------------------------------------
-- None
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity deser_1_4 is
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
end deser_1_4;

architecture xilinx of deser_1_4 is
  attribute CORE_GENERATION_INFO            : string;
  attribute CORE_GENERATION_INFO of xilinx  : architecture is "deser_1_4,selectio_wiz_v4_1,{component_name=deser_1_4,bus_dir=INPUTS,bus_sig_type=DIFF,bus_io_std=LVDS_33,use_serialization=true,use_phase_detector=false,serialization_factor=4,enable_bitslip=false,enable_train=false,system_data_width=1,bus_in_delay=FIXED,bus_out_delay=NONE,clk_sig_type=DIFF,clk_io_std=LVDS_33,clk_buf=BUFIO2,active_edge=RISING,clk_delay=FIXED,v6_bus_in_delay=NONE,v6_bus_out_delay=NONE,v6_clk_buf=BUFIO,v6_active_edge=NOT_APP,v6_ddr_alignment=SAME_EDGE_PIPELINED,v6_oddr_alignment=SAME_EDGE,ddr_alignment=C0,v6_interface_type=NETWORKING,interface_type=NETWORKING,v6_bus_in_tap=0,v6_bus_out_tap=0,v6_clk_io_std=LVCMOS18,v6_clk_sig_type=DIFF}";
  constant clock_enable            : std_logic := '1';
  signal unused : std_logic;
  signal clk_in_int                : std_logic;
  signal clk_div                   : std_logic;
  signal clk_div_int               : std_logic;
  signal clk_in_int_buf            : std_logic;
  signal clk_in_int_delay          : std_logic;


  -- After the buffer
  signal data_in_from_pins_int     : std_logic_vector(sys_w-1 downto 0);
  -- Between the delay and serdes
  signal data_in_from_pins_delay   : std_logic_vector(sys_w-1 downto 0);
  constant num_serial_bits         : integer := dev_w/sys_w;
  type serdarr is array (0 to 7) of std_logic_vector(sys_w-1 downto 0);
  -- Array to use intermediately from the serdes to the internal
  --  devices. bus "0" is the leftmost bus
  -- * fills in starting with 0
  signal iserdes_q                 : serdarr := (( others => (others => '0')));
  signal serdesstrobe             : std_logic;
  signal icascade                 : std_logic_vector(sys_w-1 downto 0);



begin




  -- Create the clock logic
  ibufds_clk_inst : IBUFGDS
    generic map (
      IOSTANDARD => "LVDS_33")
    port map (
      I          => CLK_IN_P,
      IB         => CLK_IN_N,
      O          => clk_in_int);

  -- delay the input clock
  iodelay2_clk : IODELAY2
  generic map (
     DATA_RATE             => "SDR",
     IDELAY_VALUE          => 10,
     IDELAY_TYPE           => "FIXED",
     COUNTER_WRAPAROUND    => "STAY_AT_LIMIT",
     DELAY_SRC             => "IDATAIN",
     SERDES_MODE           => "NONE",
     SIM_TAPDELAY_VALUE    => 75)
  port map (
     -- required datapath
     IDATAIN               => clk_in_int,
     DATAOUT               => clk_in_int_delay,
     T                     => '1',
     -- inactive data connections
     DATAOUT2              => open,
     DOUT                  => open,
     ODATAIN               => '0',
     TOUT                  => open,
     -- tie off the clocks
     IOCLK0                => '0',                  -- No calibration needed
     IOCLK1                => '0',                  -- No calibration needed
     -- Tie of the variable delay programming
     CLK                   => '0',
     CAL                   => '0',
     INC                   => '0',
     CE                    => '0',
     BUSY                  => open,
     RST                   => '0');

  -- Set up the clock for use in the serdes
  bufio2_inst : BUFIO2
    generic map (
      DIVIDE_BYPASS => FALSE,
      I_INVERT      => FALSE,
      USE_DOUBLER   => FALSE,
      DIVIDE        => 4)
    port map (
      DIVCLK       => clk_div,
      IOCLK        => clk_in_int_buf,
      SERDESSTROBE => serdesstrobe,
      I            => clk_in_int_delay);

   -- Buffer up the divided clock
   clkdiv_buf_inst : BUFG
     port map (
       O => clk_div_int,
       I => clk_div);

   CLK_DIV_OUT <= clk_div_int;

  
  -- We have multiple bits- step over every bit, instantiating the required elements
  pins: for pin_count in 0 to sys_w-1 generate 
  begin
    -- Instantiate the buffers
    ----------------------------------
    -- Instantiate a buffer for every bit of the data bus
     ibufds_inst : IBUFDS
       generic map (
         DIFF_TERM  => FALSE,             -- Differential termination
         IOSTANDARD => "LVDS_33")
       port map (
         I          => DATA_IN_FROM_PINS_P  (pin_count),
         IB         => DATA_IN_FROM_PINS_N  (pin_count),
         O          => data_in_from_pins_int(pin_count));

    -- Instantiate the delay primitive
    -----------------------------------
  iodelay2_bus : IODELAY2
    generic map (
      DATA_RATE                => "SDR",
      IDELAY_VALUE             => 42,
      IDELAY_TYPE              => "FIXED",
      COUNTER_WRAPAROUND       => "STAY_AT_LIMIT",
      DELAY_SRC                => "IDATAIN",
      SERDES_MODE              => "NONE",
      SIM_TAPDELAY_VALUE       => 75)
    port map (
      -- required datapath
      IDATAIN                => data_in_from_pins_int  (pin_count),
      DATAOUT                => data_in_from_pins_delay(pin_count),
      T                      => '1',
      -- inactive data connections
      DATAOUT2               => open,
      DOUT                   => open,
      ODATAIN                => '0',
      TOUT                   =>  open,
       -- connect up the clocks
      IOCLK0                => '0',                 -- No calibration needed
      IOCLK1                => '0',                 -- No calibration needed
      -- Tie of the variable delay programming
      CLK                   => '0',
      CAL                   => '0',
      INC                   => '0',
      CE                    => '0',
      BUSY                  => open,
      RST                   => '0');



     -- Instantiate the serdes primitive
     ----------------------------------
     -- declare the iserdes
     iserdes2_master : ISERDES2
       generic map (
         BITSLIP_ENABLE => FALSE,
         DATA_RATE      => "SDR",
         DATA_WIDTH     => 4,
         INTERFACE_TYPE => "NETWORKING",
         SERDES_MODE    => "NONE")
       port map (
         Q1         => iserdes_q(3)(pin_count),
         Q2         => iserdes_q(2)(pin_count),
         Q3         => iserdes_q(1)(pin_count),
         Q4         => iserdes_q(0)(pin_count),
         SHIFTOUT   => open,
         INCDEC     => open,
         VALID      => open,
         BITSLIP    => '0',
         CE0        => clock_enable,   -- 1-bit Clock enable input
         CLK0       => clk_in_int_buf, -- 1-bit IO Clock network input. Optionally Invertible. This is the primary clock
                                       -- input used when the clock doubler circuit is not engaged (see DATA_RATE
                                       -- attribute).
         CLK1       => '0',
         CLKDIV     => clk_div_int,                        -- 1-bit Global clock network input. This is the clock for the fabric domain.
         D          => data_in_from_pins_delay(pin_count), -- 1-bit Input signal from IOB.
         IOCE       => serdesstrobe,                       -- 1-bit Data strobe signal derived from BUFIO CE. Strobes data capture for
                                                          -- NETWORKING and NETWORKING_PIPELINES alignment modes.

         RST        => IO_RESET,        -- 1-bit Asynchronous reset only.
         SHIFTIN    => '0',


        -- unused connections
         FABRICOUT  => open,
         CFB0       => open,
         CFB1       => open,
         DFB        => open);




     -- Concatenate the serdes outputs together. Keep the timesliced
     --   bits together, and placing the earliest bits on the right
     --   ie, if data comes in 0, 1, 2, 3, 4, 5, 6, 7, ...
     --       the output will be 3210, 7654, ...
     -------------------------------------------------------------

     in_slices: for slice_count in 0 to num_serial_bits-1 generate begin
        -- This places the first data in time on the right
        DATA_IN_TO_DEVICE(slice_count) <=
          iserdes_q(num_serial_bits-slice_count-1)(0);
        -- To place the first data in time on the left, use the
        --   following code, instead
        -- DATA_IN_TO_DEVICE(slice_count) <=
        --   iserdes_q(slice_count);
     end generate in_slices;


  end generate pins;





end xilinx;



