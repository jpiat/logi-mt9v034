--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:48:22 07/01/2015
-- Design Name:   
-- Module Name:   /home/jpiat/development/FPGA/logi-family/logi-mt9v034/hw/logipi/hdl/i2c_master_tb.vhd
-- Project Name:  logipi_mt9v034
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: i2c_master
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY i2c_master_tb IS
END i2c_master_tb;
 
ARCHITECTURE behavior OF i2c_master_tb IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT i2c_master
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         slave_addr : IN  std_logic_vector(6 downto 0);
         data_in : IN  std_logic_vector(7 downto 0);
         i2c_read : IN  std_logic;
         i2c_write : IN  std_logic;
         scl : INOUT  std_logic;
         sda : INOUT  std_logic;
         data_out : OUT  std_logic_vector(7 downto 0);
         new_data : OUT  std_logic;
         ack : OUT  std_logic;
         nack : OUT  std_logic;
         busy : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal slave_addr : std_logic_vector(6 downto 0) := (others => '0');
   signal data_in : std_logic_vector(7 downto 0) := (others => '0');
   signal i2c_read : std_logic := '0';
   signal i2c_write : std_logic := '0';

	--BiDirs
   signal scl : std_logic;
   signal sda : std_logic;

 	--Outputs
   signal data_out : std_logic_vector(7 downto 0);
   signal new_data : std_logic;
   signal ack : std_logic;
   signal nack : std_logic;
   signal busy : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: i2c_master PORT MAP (
          clk => clk,
          reset => reset,
          slave_addr => slave_addr,
          data_in => data_in,
          i2c_read => i2c_read,
          i2c_write => i2c_write,
          scl => scl,
          sda => sda,
          data_out => data_out,
          new_data => new_data,
          ack => ack,
          nack => nack,
          busy => busy
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
 

   -- Stimulus process
   stim_proc: process
   begin		
      -- hold reset state for 100 ns.
		reset <= '1' ;
		slave_addr <= "0101000" ;
		sda <= 'Z' ;
		scl <= 'Z' ;
      wait for 100 ns;	
		reset <= '0' ;
		i2c_write <= '1' ;
		data_in <= X"B1";
      wait for (clk_period*1000) * 9 ;
		sda <= '0' ;
		wait for clk_period*1000;
		sda <= 'Z' ;
		wait for (clk_period*1000) * 8 ;
		sda <= '0' ;
		wait for clk_period*1000;
		sda <= 'Z' ;
		
      -- insert stimulus here 

      wait;
   end process;

END;
