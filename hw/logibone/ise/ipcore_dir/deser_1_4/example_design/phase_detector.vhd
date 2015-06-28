-- file: phase_detector.vhd
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
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all ;

library unisim ;
use unisim.vcomponents.all ;

entity phase_detector is generic (
	D 			: integer := 16) ;				-- Set the number of inputs
port 	(
	use_phase_detector	:  in std_logic ;				-- Set generation of phase detector logic
	busy			:  in std_logic_vector(D-1 downto 0) ;		-- BUSY inputs from IODELAY2s
	valid			:  in std_logic_vector(D-1 downto 0) ;		-- VALID inputs from IODELAY2s
	inc_dec			:  in std_logic_vector(D-1 downto 0) ;		-- INC_DEC inputs from ISERDES2s
	reset			:  in std_logic ;				-- Reset line
	gclk			:  in std_logic ;				-- Global clock
	debug_in  		:  in std_logic_vector(1 downto 0) ;		-- input debug data
	cal_master		: out std_logic ;				-- Output to cal pins on master IODELAY2s
	cal_slave		: out std_logic ;				-- Output to cal pins on slave IODELAY2s
	rst_out			: out std_logic ;				-- Output to rst pins on master & slave IODELAY2s
	ce			: out std_logic_vector(D-1 downto 0) ;  	-- Outputs to ce pins on IODELAY2s
	inc			: out std_logic_vector(D-1 downto 0) ;  	-- Outputs to inc pins on IODELAY2s
	debug			: out std_logic_vector((3*D)+5 downto 0)) ;  	-- Debug bus, 3D+5 = 3 lines per input (from inc, mux and ce) + 6, leave nc if debug not required
end phase_detector ;

architecture arch_phase_detector of phase_detector is
  
signal	state 			: integer range 0 to 15 ;
signal	busyd 			: std_logic_vector(D-1 downto 0) ;
signal	cal_data_sint		: std_logic ;
signal	ce_data_inta		: std_logic ;
signal	busy_data_d		: std_logic ;
signal	counter			: std_logic_vector(11 downto 0) ;
signal	enable			: std_logic ;
signal	pd_edge			: std_logic_vector(D-1 downto 0) ;
signal	cal_data_slave		: std_logic ;
signal	cal_data_master		: std_logic ;
signal	valid_data_d		: std_logic ;
signal	rst_data		: std_logic ;
signal	mdataout 		: std_logic_vector((8*D)-1 downto 0) ;
signal 	pdcounter 		: std_logic_vector(4 downto 0) ;
signal	inc_data		: std_logic ;
signal	ce_data			: std_logic_vector(D-1 downto 0) ;
signal	inc_data_int		: std_logic ;
signal	incdec_data_d		: std_logic ;
signal	inc_data_int_d		: std_logic_vector(D-1 downto 0) ;
signal	mux			: std_logic_vector(D-1 downto 0) ;
signal	incdec_data_or		: std_logic_vector(D downto 0) ;
signal	valid_data_or		: std_logic_vector(D downto 0) ;
signal	busy_data_or		: std_logic_vector(D downto 0) ;
signal	incdec_data_im		: std_logic_vector(D-1 downto 0) ;
signal	valid_data_im		: std_logic_vector(D-1 downto 0) ;
signal	all_ce			: std_logic_vector(D-1 downto 0) ;
signal	all_inc			: std_logic_vector(D-1 downto 0) ;

begin

debug <= mux & cal_data_master & rst_data & cal_data_sint & busy_data_d & inc_data_int_d & ce_data & valid_data_d & incdec_data_d ;
cal_slave <= cal_data_sint ;
cal_master <= cal_data_master ;
rst_out <= rst_data ;
ce <= ce_data ;
inc <= inc_data_int_d ;

process (gclk, reset)
begin
if reset = '1' then
	state <= 0 ;
	cal_data_master <= '0' ;
	cal_data_sint <= '0' ;
	counter <= (others => '0') ;
	enable <= '0' ;
	counter <= (others => '0') ;
	mux(0) <= '1';
        mux(D-1 downto 1) <= (others => '0');
elsif gclk'event and gclk = '1' then
   	if counter(11) = '1' then
		counter <= (others => '0') ;
   	else
   		counter <= counter + 1 ;
   	end if ;
   	if counter(5) = '1' then
		enable <= '1' ;
   	end if ;
  	case (state) is
  	when 0 =>	
  		if enable = '1' then			-- Wait for all IODELAYs to be available
			cal_data_master <= '0' ;
			cal_data_sint <= '0' ;
			rst_data <= '0' ;
   			if busy_data_d = '0' then
				state <= 1 ;
			end if ;
		end if ;
   	when 1 => 					-- Issue calibrate command to both master and slave
   		cal_data_master <= '1' ;
   		cal_data_sint <= '1' ;
   		if busy_data_d = '1' then		-- and wait for command to be accepted
   			state <= 2 ;
   		end if ;
   	when 2 => 					-- Now RST all master and slave IODELAYs
   		cal_data_master <= '0' ;
   		cal_data_sint <= '0' ;
   		if busy_data_d = '0' then
   			rst_data <= '1' ;
   			state <= 3 ;
   		end if ;
   	when 3 =>					-- Wait for all IODELAYs to be busy
   		rst_data <= '0' ;
   		if busy_data_d = '1' then
   			state <= 4 ;
   		end if ;
   	when 4 => 					-- Wait for all IODELAYs to be available
   		if busy_data_d = '0' then
  		 	state <= 5 ;
   		end if ;
   	when 5 => 					-- Wait for occasional enable
   		if counter(11) = '1' then
  		 	state <= 6 ;
   		end if ;
    	when 6 =>					-- Calibrate slave only
   		if busy_data_d = '0' then
   			cal_data_sint <= '1' ;
   			state <= 7 ;
   			if D /= 1 then
   				mux <= mux(D-2 downto 0) & mux(D-1) ;
   			end if ;
   		end if ;
    	when 7 =>					-- Wait for command to be accepted
   		if busy_data_d = '1' then
   			cal_data_sint <= '0' ;
   			state <= 8 ;
   		end if ;
   	when 8 =>					-- Wait for all IODELAYs to be available, ie CAL command finished
    		cal_data_sint <= '0' ;
  		if busy_data_d = '0' then
   			state <= 5 ;
   		end if ;
   	when others => 
   		state <= 0 ;
   	end case ;
end if ;
end process ;

process (gclk, reset)
begin
if reset = '1' then
	pdcounter <= "10000" ;
	ce_data_inta <= '0' ;
	inc_data_int <= '0' ;
elsif gclk'event and gclk = '1' then
	busy_data_d <= busy_data_or(D) ;
	incdec_data_d <= incdec_data_or(D) ;
	valid_data_d <= valid_data_or(D) ;
   	if use_phase_detector = '1' then					-- decide whther pd is used
		if ce_data_inta = '1' then
			ce_data <= mux ;
			if inc_data_int = '1' then
				inc_data_int_d <= mux ;
			end if ;
		else 
			ce_data <= (others => '0') ;
			inc_data_int_d <= (others => '0') ;
		end if ;
   		if state /= 5 or busy_data_d = '1' then				-- Reset filter if state machine issues a cal command or unit is busy
			pdcounter <= "10000" ;
   			ce_data_inta <= '0' ;
   			inc_data_int <= '0' ;
   		elsif pdcounter = "11111" then					-- Filter has reached positive max - increment the tap count
   			ce_data_inta <= '1' ;
   			inc_data_int <= '1' ;
 			pdcounter <= "10000" ;
    		elsif pdcounter = "00000" then					-- Filter has reached negative max - decrement the tap count
   			ce_data_inta <= '1' ;
   			inc_data_int <= '0' ;
 			pdcounter <= "10000" ;
		elsif valid_data_d = '1' then					-- increment filter
   			ce_data_inta <= '0' ;
			inc_data_int <= '0' ;
			if incdec_data_d = '1' then
				pdcounter <= pdcounter + 1 ;
			elsif incdec_data_d = '0' then 				-- decrement filter
				pdcounter <= pdcounter - 1 ;
			end if ;
   		else 
   			ce_data_inta <= '0' ;
 			inc_data_int <= '0' ;
  		end if ;
   	else
   		ce_data <= all_ce ;
		inc_data_int_d <= all_inc ;
	end if ;
end if ;
end process ;

incdec_data_or(0) <= '0' ;							-- Input Mux - Initialise generate loop OR gates
valid_data_or(0) <= '0' ;
busy_data_or(0) <= '0' ;

loop0 : for i in 0 to (D - 1) generate

incdec_data_im(i) <= inc_dec(i) and mux(i) ;					-- Input muxes
incdec_data_or(i+1) <= incdec_data_im(i) or incdec_data_or(i) ;			-- AND gates to allow just one signal through at a tome
valid_data_im(i) <= valid(i) and mux(i) ;					-- followed by an OR
valid_data_or(i+1) <= valid_data_im(i) or valid_data_or(i) ;			-- for the three inputs from each PD
busy_data_or(i+1) <= busy(i) or busy_data_or(i) ;				-- The busy signals just need an OR gate

all_ce(i) <= debug_in(0) ;
all_inc(i) <= debug_in(1) ;

end generate ;

end arch_phase_detector ;
