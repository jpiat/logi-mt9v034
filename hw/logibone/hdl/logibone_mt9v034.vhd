library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;
use ieee.numeric_std.ALL;

library UNISIM;
use UNISIM.VComponents.all;

library work ;
use work.logi_wishbone_pack.all ;
use work.logi_wishbone_peripherals_pack.all ;
use work.image_pack.all ;


entity logibone_mt9v034 is
	port(
		OSC_FPGA : in std_logic ;
		LED :   out  std_logic_vector((2-1) downto 0);
		ARD_SCL, ARD_SDA : inout std_logic;
		
		--gpmc interface
		GPMC_CSN : in std_logic ;
		GPMC_BEN:	in std_logic_vector(1 downto 0);
		GPMC_WEN, GPMC_OEN, GPMC_ADVN :	in std_logic;
		GPMC_CLK :	in std_logic;
		GPMC_AD :	inout std_logic_vector(15 downto 0)	;
		-- SATA INTERFACE
		SATA_DATA_P, SATA_DATA_N : in std_logic ;
		SATA_CLK_P, SATA_CLK_N : in std_logic ;
		
		PMOD1 : inout std_logic_vector(7 downto 0);
		
		
		-- DRAM INTERFACE
		
		SDRAM_CLK   : out   STD_LOGIC;
		SDRAM_CKE   : out   STD_LOGIC;
		--SDRAM_CS    : out   STD_LOGIC;
		SDRAM_nRAS  : out   STD_LOGIC;
		SDRAM_nCAS  : out   STD_LOGIC;
		SDRAM_nWE   : out   STD_LOGIC;
		SDRAM_DQM   : out   STD_LOGIC_VECTOR( 1 downto 0);
		SDRAM_ADDR  : out   STD_LOGIC_VECTOR (12 downto 0);
		SDRAM_BA    : out   STD_LOGIC_VECTOR( 1 downto 0);
		SDRAM_DQ    : inout STD_LOGIC_VECTOR (15 downto 0)
	);
end logibone_mt9v034;

architecture structural of logibone_mt9v034 is

constant sdram_address_width : natural := 24;
constant sdram_column_bits   : natural := 9;
constant sdram_startup_cycles: natural := 10100; -- 100us, plus a little more
constant cycles_per_refresh  : natural := (64000*100)/8192-1;	

component wishbone_dram_fifo is
generic( ADDR_WIDTH: positive := 16; --! width of the address bus
			WIDTH	: positive := 16; --! width of the data bus
			FIFO_SIZE : positive := 8_000_000; --! fifo depth;
			BURST_SIZE : positive := 4;
			THRESHOLD : positive := 4;
			SYNC_LOGIC_INTERFACE : boolean := false;
			IS_READ : boolean := true ;
			sdram_address_width : positive := 24;
			CACHE_ADDRESS : std_logic_vector(31 downto 0) := (others => '0')
			); 
port(
	-- Syscon signals
	gls_reset    : in std_logic ;
	gls_clk      : in std_logic ;
	-- Wishbone signals
	wbs_address       : in std_logic_vector(ADDR_WIDTH-1 downto 0) ;
	wbs_writedata : in std_logic_vector( WIDTH-1 downto 0);
	wbs_readdata  : out std_logic_vector( WIDTH-1 downto 0);
	wbs_strobe    : in std_logic ;
	wbs_cycle      : in std_logic ;
	wbs_write     : in std_logic ;
	wbs_ack       : out std_logic;
		  
	refresh_active, flush_active : out std_logic ;	  
		  
	-- logic signals
	write_fifo, read_fifo : in std_logic ;
	fifo_input: in std_logic_vector((WIDTH - 1) downto 0); --! data input of fifo B
	fifo_output	: out std_logic_vector((WIDTH - 1) downto 0); --! data output of fifo A
	
	fifo_empty, fifo_full : out std_logic ;
	fifo_reset : out std_logic ;
	fifo_threshold : out std_logic;
	
	-- Interface to issue reads or write data
	cmd_ready         : in STD_LOGIC;                     -- '1' when a new command will be acted on
	cmd_enable        : out  STD_LOGIC;                     -- Set to '1' to issue new command (only acted on when cmd_read = '1')
	cmd_wr            : out  STD_LOGIC;                     -- Is this a write?
	cmd_address       : out  STD_LOGIC_VECTOR(sdram_address_width-2 downto 0); -- address to read/write
	cmd_byte_enable   : out  STD_LOGIC_VECTOR(3 downto 0);  -- byte masks for the write command
	cmd_data_in       : out  STD_LOGIC_VECTOR(31 downto 0); -- data for the write command

	sdram_data_out         : in STD_LOGIC_VECTOR(31 downto 0); -- word read from SDRAM
	sdram_data_ready    : in STD_LOGIC
);
end component;


	COMPONENT SDRAM_Controller
    generic (
      sdram_address_width : natural;
      sdram_column_bits   : natural;
      sdram_startup_cycles: natural;
      cycles_per_refresh  : natural;
		very_low_speed : natural := 0
    );
    PORT(
		clk             : IN std_logic;
		reset           : IN std_logic;
      
      -- Interface to issue commands
		cmd_ready       : OUT std_logic;
		cmd_enable      : IN  std_logic;
		cmd_wr          : IN  std_logic;
      cmd_address     : in  STD_LOGIC_VECTOR(sdram_address_width-2 downto 0); -- address to read/write
		cmd_byte_enable : IN  std_logic_vector(3 downto 0);
		cmd_data_in     : IN  std_logic_vector(31 downto 0);    
      
      -- Data being read back from SDRAM
		data_out        : OUT std_logic_vector(31 downto 0);
		data_out_ready  : OUT std_logic;

      -- SDRAM signals
		SDRAM_CLK       : OUT   std_logic;
		SDRAM_CKE       : OUT   std_logic;
		SDRAM_CS        : OUT   std_logic;
		SDRAM_RAS       : OUT   std_logic;
		SDRAM_CAS       : OUT   std_logic;
		SDRAM_WE        : OUT   std_logic;
		SDRAM_DQM       : OUT   std_logic_vector(1 downto 0);
		SDRAM_ADDR      : OUT   std_logic_vector(12 downto 0);
		SDRAM_BA        : OUT   std_logic_vector(1 downto 0);
		SDRAM_DATA      : INOUT std_logic_vector(15 downto 0)     
		);
	END COMPONENT;

component deser_1_4
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


component cam_deser_4_to_pixels_v2 is
generic(INVERT_DATA : boolean := true);
port(
	deser_clk, sys_clk : in std_logic ;
	sys_reset : in std_logic ;
	data_in_deser : in std_logic_vector(3 downto 0);
	
	raw_deser : out std_logic_vector(9 downto 0);

	
	pixel_out_clk, pixel_out_hsync, pixel_out_vsync : out std_logic ;
	pixel_out_data : out std_logic_vector(7 downto 0);
	synced_out : out std_logic 
);
end component;


component heart_beat is
    generic(clk_period_ns : positive := 10; 
				beat_period_ns : positive := 900_000_000;
				beat_length_ns : positive := 100_000_000);
	 port ( gls_clk : in  STD_LOGIC;
           gls_reset : in  STD_LOGIC;
           beat_out : out  STD_LOGIC);
end component;	

	type wishbone_bus is
	record
		address : std_logic_vector(15 downto 0);
		writedata : std_logic_vector(15 downto 0);
		readdata : std_logic_vector(15 downto 0);
		cycle: std_logic;
		write : std_logic;
		strobe : std_logic;
		ack : std_logic;
	end record;
	
signal Master_0_wbm_Intercon_0_wbs_0 : wishbone_bus;	
signal Intercon_0_wbm_REG_0_wbs_0 : wishbone_bus;
signal Intercon_0_wbm_FIFO_0_wbs_0 : wishbone_bus;




signal gls_clk, gls_clk_unbuf, gls_reset, gls_resetn, DESER_CLK_DIV, clk_locked, clkfb, osc_buff : std_logic ;
signal deser_data : std_logic_vector(3 downto 0);
signal sync_errors : std_logic_vector(15 downto 0);
signal synced, synced_old, pixel_out_clk : std_logic ;
signal pixel_data, pixel_data_latched : std_logic_vector(7 downto 0);
signal raw_deser_latched, raw_deser : std_logic_vector(9 downto 0);


-- pixel pipeline 
signal CAM_0_pixel_y_out_FIFO_0_pixel_in : y_pixel_bus;

signal fifo_write, pipeline_reset : std_logic ;
signal fifo_data : std_logic_vector(15 downto 0);

-- sdram signals

signal cmd_address     : std_logic_vector(sdram_address_width-2 downto 0) := (others => '0');
signal cmd_wr          : std_logic := '1';
signal cmd_enable      : std_logic;
signal cmd_byte_enable : std_logic_vector(3 downto 0);
signal cmd_data_in     : std_logic_vector(31 downto 0);
signal cmd_ready       : std_logic;
signal data_out        : std_logic_vector(31 downto 0);
signal data_out_ready  : std_logic;

begin


gls_reset <= (NOT clk_locked); -- system reset while clock not locked
gls_resetn <= NOT gls_reset ;
ARD_SCL <= 'Z';
--'Z' <= ARD_SCL;
ARD_SDA <= 'Z';
--'Z' <= ARD_SDA;


gpmc2wishbone : gpmc_wishbone_wrapper 
generic map(sync => true, burst => false)
port map
    (
      -- GPMC SIGNALS
      gpmc_ad => GPMC_AD, 
      gpmc_csn => GPMC_CSN,
      gpmc_oen => GPMC_OEN,
		gpmc_wen => GPMC_WEN,
		gpmc_advn => GPMC_ADVN,
		gpmc_clk => GPMC_CLK,
		
      -- Global Signals
      gls_reset => gls_reset,
      gls_clk   => gls_clk,
      -- Wishbone interface signals
     wbm_address =>  Master_0_wbm_Intercon_0_wbs_0.address,
		wbm_writedata =>  Master_0_wbm_Intercon_0_wbs_0.writedata,
		wbm_readdata =>  Master_0_wbm_Intercon_0_wbs_0.readdata,
		wbm_cycle =>  Master_0_wbm_Intercon_0_wbs_0.cycle,
		wbm_strobe =>  Master_0_wbm_Intercon_0_wbs_0.strobe,
		wbm_write =>  Master_0_wbm_Intercon_0_wbs_0.write,
		wbm_ack =>  Master_0_wbm_Intercon_0_wbs_0.ack	
    );
	 
	 
intercon0 : wishbone_intercon
generic map(memory_map => 
(
"000100000000000X", -- reg0
"000000XXXXXXXXXX"
)
)
port map(
		gls_reset => gls_reset,
		gls_clk   => gls_clk,
		
		
		wbs_address =>  Master_0_wbm_Intercon_0_wbs_0.address,
		wbs_writedata =>  Master_0_wbm_Intercon_0_wbs_0.writedata,
		wbs_readdata =>  Master_0_wbm_Intercon_0_wbs_0.readdata,
		wbs_cycle =>  Master_0_wbm_Intercon_0_wbs_0.cycle,
		wbs_strobe =>  Master_0_wbm_Intercon_0_wbs_0.strobe,
		wbs_write =>  Master_0_wbm_Intercon_0_wbs_0.write,
		wbs_ack =>  Master_0_wbm_Intercon_0_wbs_0.ack,
		-- Wishbone master signals
		wbm_address(0) =>  Intercon_0_wbm_REG_0_wbs_0.address,
		wbm_address(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.address,

		wbm_writedata(0) =>  Intercon_0_wbm_REG_0_wbs_0.writedata,
		wbm_writedata(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.writedata,	
		
		wbm_readdata(0) =>  Intercon_0_wbm_REG_0_wbs_0.readdata,
		wbm_readdata(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.readdata,

		wbm_cycle(0) =>  Intercon_0_wbm_REG_0_wbs_0.cycle,
		wbm_cycle(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.cycle,


		wbm_strobe(0) =>  Intercon_0_wbm_REG_0_wbs_0.strobe,
		wbm_strobe(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.strobe,	
		
		wbm_write(0) =>  Intercon_0_wbm_REG_0_wbs_0.write,
		wbm_write(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.write,

		wbm_ack(0) =>  Intercon_0_wbm_REG_0_wbs_0.ack,
		wbm_ack(1) =>  Intercon_0_wbm_FIFO_0_wbs_0.ack

	
		
);
	reg0 : wishbone_register
	generic map(
		  nb_regs => 2
	 )
	 port map
	 (
			gls_reset => gls_reset,
			gls_clk   => gls_clk,


			wbs_address    => Intercon_0_wbm_REG_0_wbs_0.address,  	
			wbs_readdata   => Intercon_0_wbm_REG_0_wbs_0.readdata,  	
			wbs_writedata 	=> Intercon_0_wbm_REG_0_wbs_0.writedata,  
			wbs_strobe     => Intercon_0_wbm_REG_0_wbs_0.strobe,      
			wbs_write      => Intercon_0_wbm_REG_0_wbs_0.write,    
			wbs_ack        => Intercon_0_wbm_REG_0_wbs_0.ack,    
			wbs_cycle      => Intercon_0_wbm_REG_0_wbs_0.cycle, 
			
			reg_in(0) => sync_errors,
			reg_in(1)(15 downto 10) => (others => '0'),
			reg_in(1)(9 downto 0) => raw_deser_latched,
			reg_out(0)(15 downto 1) => open,
			reg_out(0)(0)=> pipeline_reset,
			reg_out(1)=> open
	 );		



cam_deser_0 : deser_1_4
  port map
   (
  -- From the system into the device
  DATA_IN_FROM_PINS_P(0) =>   SATA_DATA_P, --Input pins
  DATA_IN_FROM_PINS_N(0) =>   SATA_DATA_N, --Input pins
  DATA_IN_TO_DEVICE =>   deser_data, --Output pins

  
-- Clock and reset signals
  CLK_IN_P =>   SATA_CLK_P,     -- Differential clock from IOB
  CLK_IN_N =>   SATA_CLK_N,     -- Differential clock from IOB
  CLK_DIV_OUT =>   DESER_CLK_DIV,     -- Slow clock output
  CLK_RESET =>   gls_reset,         --clocking logic reset
  IO_RESET =>   gls_reset);          --system reset


cam_0 : cam_deser_4_to_pixels_v2
generic map(INVERT_DATA => true)
port map(
	deser_clk => DESER_CLK_DIV, 
	sys_clk => gls_clk,
	sys_reset => gls_reset,
	data_in_deser => deser_data,
	
	raw_deser => raw_deser ,
	
	pixel_out_clk => CAM_0_pixel_y_out_FIFO_0_pixel_in.clk, 
	pixel_out_hsync => CAM_0_pixel_y_out_FIFO_0_pixel_in.hsync, 
	pixel_out_vsync => CAM_0_pixel_y_out_FIFO_0_pixel_in.vsync,
	pixel_out_data => CAM_0_pixel_y_out_FIFO_0_pixel_in.data,
	synced_out => synced
);
--synced <= CAM_0_pixel_y_out_FIFO_0_pixel_in.vsync ;
--led(0) <= synced ;

FiFO_0 : wishbone_dram_fifo 
generic map(ADDR_WIDTH => 16,
			WIDTH => 16, 
			FIFO_SIZE => 8_000_000, 
			BURST_SIZE => 512,
			SYNC_LOGIC_INTERFACE => true,
			IS_READ => true,
			sdram_address_width => sdram_address_width,
			CACHE_ADDRESS => X"00000000"
			)
port map(
	gls_clk => gls_clk, 
	gls_reset => gls_reset,

	wbs_address =>  Intercon_0_wbm_FIFO_0_wbs_0.address,
	wbs_writedata =>  Intercon_0_wbm_FIFO_0_wbs_0.writedata,
	wbs_readdata =>  Intercon_0_wbm_FIFO_0_wbs_0.readdata,
	wbs_cycle =>  Intercon_0_wbm_FIFO_0_wbs_0.cycle,
	wbs_strobe =>  Intercon_0_wbm_FIFO_0_wbs_0.strobe,
	wbs_write =>  Intercon_0_wbm_FIFO_0_wbs_0.write,
	wbs_ack =>  Intercon_0_wbm_FIFO_0_wbs_0.ack,
		  
	-- logic signals
	write_fifo => fifo_write, 
	read_fifo => '0',
	fifo_input => fifo_data,
	fifo_output => open,
	fifo_empty => open, 
	fifo_full => open,
	fifo_threshold => open,
	
	
	cmd_address     => cmd_address,
	cmd_wr          => cmd_wr,
	cmd_enable      => cmd_enable,
	cmd_ready       => cmd_ready,
	cmd_byte_enable => cmd_byte_enable,
	cmd_data_in     => cmd_data_in, 
	
	sdram_data_out        => data_out,
   sdram_data_ready  => data_out_ready
);

YUV_TO_FIFO_0: yuv_to_fifo
port map(
	clk => gls_clk, 
	resetn =>  gls_resetn,
	sreset => pipeline_reset,
	pixel_in_clk =>  CAM_0_pixel_y_out_FIFO_0_pixel_in.clk,
	pixel_in_hsync =>  CAM_0_pixel_y_out_FIFO_0_pixel_in.hsync,
	pixel_in_vsync =>  CAM_0_pixel_y_out_FIFO_0_pixel_in.vsync,
	pixel_in_y_data => CAM_0_pixel_y_out_FIFO_0_pixel_in.data,
	pixel_in_u_data => X"80",
	pixel_in_v_data => X"80",
	fifo_data => fifo_data,
	fifo_wr => fifo_write 

);

PMOD1(0) <= synced ;

PMOD1(1) <= CAM_0_pixel_y_out_FIFO_0_pixel_in.vsync;
PMOD1(2) <= CAM_0_pixel_y_out_FIFO_0_pixel_in.hsync;

LED(0) <= CAM_0_pixel_y_out_FIFO_0_pixel_in.vsync;

process(gls_clk, gls_reset)
begin
	if gls_reset = '1' then
		sync_errors <= (others => '0');
		pixel_data_latched <= (others => '0');
		raw_deser_latched <= (others => '0');
	elsif gls_clk'event and gls_clk = '1' then
		if synced_old = '1' and synced = '0' then
			sync_errors <= sync_errors + 1 ;
		end if ;
		raw_deser_latched <= raw_deser ;
		if pixel_out_clk = '1' then
			pixel_data_latched <= pixel_data ;
		end if ;
		synced_old <= synced ;
	end if ;
end process ;


Inst_SDRAM_Controller: SDRAM_Controller
	GENERIC MAP (
      sdram_address_width => sdram_address_width,
      sdram_column_bits   => sdram_column_bits,
      sdram_startup_cycles=> sdram_startup_cycles,
      cycles_per_refresh  => cycles_per_refresh,
		very_low_speed => 0 -- only when using controller in sub 80Mhz
   ) PORT MAP(
      clk             => gls_clk,
      reset           => '0',

      cmd_address     => cmd_address,
      cmd_wr          => cmd_wr,
      cmd_enable      => cmd_enable,
      cmd_ready       => cmd_ready,
      cmd_byte_enable => cmd_byte_enable,
      cmd_data_in     => cmd_data_in,
      
      data_out        => data_out,
      data_out_ready  => data_out_ready,
   
      SDRAM_CLK       => SDRAM_CLK,
      SDRAM_CKE       => SDRAM_CKE,
      SDRAM_CS        => open,
      SDRAM_RAS       => SDRAM_nRAS,
      SDRAM_CAS       => SDRAM_nCAS,
      SDRAM_WE        => SDRAM_nWE,
      SDRAM_DQM       => SDRAM_DQM,
      SDRAM_BA        => SDRAM_BA,
      SDRAM_ADDR      => SDRAM_ADDR,
      SDRAM_DATA      => SDRAM_DQ
   );


beat_0  :heart_beat
	 generic map(clk_period_ns => 10)
	 port map ( gls_clk => DESER_CLK_DIV,
           gls_reset => gls_reset,
           beat_out => led(1));		  
-- system clock generation

PLL_BASE_inst : PLL_BASE generic map (
      BANDWIDTH      => "OPTIMIZED",        -- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT  => 12 ,                 -- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE => 0.0,                -- Phase offset in degrees of the clock feedback output (0.0-360.0).
      CLKIN_PERIOD   => 20.00,              -- Input clock period in ns to ps resolution (i.e. 33.333 is 30 MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE => 6,       CLKOUT1_DIVIDE =>1,
      CLKOUT2_DIVIDE => 1,       CLKOUT3_DIVIDE => 1,
      CLKOUT4_DIVIDE => 1,       CLKOUT5_DIVIDE => 1,
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE => 0.5, CLKOUT1_DUTY_CYCLE => 0.5,
      CLKOUT2_DUTY_CYCLE => 0.5, CLKOUT3_DUTY_CYCLE => 0.5,
      CLKOUT4_DUTY_CYCLE => 0.5, CLKOUT5_DUTY_CYCLE => 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE => 0.0,      CLKOUT1_PHASE => 0.0, -- Capture clock
      CLKOUT2_PHASE => 0.0,      CLKOUT3_PHASE => 0.0,
      CLKOUT4_PHASE => 0.0,      CLKOUT5_PHASE => 0.0,
      
      CLK_FEEDBACK => "CLKFBOUT",           -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION => "SYSTEM_SYNCHRONOUS", -- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE => 1,                   -- Division value for all output clocks (1-52)
      REF_JITTER => 0.1,                    -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        -- Must be set to FALSE
   ) port map (
      CLKFBOUT => clkfb, -- 1-bit output: PLL_BASE feedback output
      -- CLKOUT0 - CLKOUT5: 1-bit (each) output: Clock outputs
      CLKOUT0 => gls_clk_unbuf,      CLKOUT1 => open,
      CLKOUT2 => open,      CLKOUT3 => open,
      CLKOUT4 => open,      CLKOUT5 => open,
      LOCKED  => clk_locked,  -- 1-bit output: PLL_BASE lock status output
      CLKFBIN => clkfb, -- 1-bit input: Feedback clock input
      CLKIN   => osc_buff,  -- 1-bit input: Clock input
      RST     => '0'    -- 1-bit input: Reset input
   );

    -- Buffering of clocks
	BUFG_1 : BUFG port map (O => osc_buff,    I => OSC_FPGA);
	BUFG_2 : BUFG port map (O => gls_clk,    I => gls_clk_unbuf);


end structural ;