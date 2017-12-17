----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:05:22 11/15/2017 
-- Design Name: 
-- Module Name:    MotorCntrlTop - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity MotorCntrlTop is

	port(
		clk: in std_logic;
		
		RX_in : in std_logic; --UART receive pin
		TX_out : out std_logic;	-- UART send pin
		
		D0 : out std_logic_vector ( 1 downto 0); -- Phase A input for two motors
		D1 : out std_logic_vector (1 downto 0); -- Phase B output for two motors
		
		btnL : in std_logic; -- pause button
		btnR : in std_logic; --reset button
		
		led : out std_logic_vector(15 downto 0)
	);
end MotorCntrlTop;

architecture Behavioral of MotorCntrlTop is

 component motorCtrl is
	port(
		clk		: IN std_logic;
		--sw: in std_logic_vector(7 downto 0);
		rst 		: in std_logic;
		phaseA 	: out std_logic;
		phaseB 	: out std_Logic;
		ncmd		: out std_logic;
		st 		: out std_logic_vector(2 downto 0);
		trig 		: out std_logic;
		sp 		: out std_logic_vector(7 downto 0);
		pause 	: in std_logic;
		newSpd 	: in std_logic; --flag for new speed value
		newCommand : in std_logic; --flag for new command 
		cmd 		: in std_logic_vector(7 Downto 0)
	);
	end component motorCtrl;

 component uart_tx is
    generic (
      g_CLKS_PER_BIT : integer := 10417  -- Needs to be set correctly
      );
    port (
      i_clk       : in  std_logic;
      i_tx_dv     : in  std_logic;
      i_tx_byte   : in  std_logic_vector(7 downto 0);
      o_tx_active : out std_logic;
      o_tx_serial : out std_logic;
      o_tx_done   : out std_logic
      );
  end component uart_tx;
 
  component uart_rx is
    generic (
      g_CLKS_PER_BIT : integer := 10417   -- Needs to be set correctly
      );
    port (
      i_clk       : in  std_logic;
      i_rx_serial : in  std_logic;
      o_rx_dv     : out std_logic;
      o_rx_byte   : out std_logic_vector(7 downto 0)
      );
  end component uart_rx;
  
 -- declare signals 
  signal rst : std_logic;
 
  signal PA : std_logic_vector(1 downto 0):= (others => '0');
  signal PB : std_logic_vector(1 downto 0):= (others => '0');
  signal pause : std_logic;
  
  signal newCmd : std_logic_vector(1 downto 0):= (others => '0'); -- tells motor controller core if it should receive command
  signal newspd : std_logic_vector(1 downto 0):= (others => '0'); -- flag for which motor controller is getting the new speed
  signal address : std_logic_vector(7 downto 0):= (others => '0'); -- address for which motor controller is being accessed
  signal speed : std_logic_vector(7 downto 0):= (others => '0'); -- speed to send to motor controller
  signal cmd : std_logic_vector(7 downto 0):= (others => '0'); -- internal command byte
  
  signal st0: std_logic_vector(2 downto 0):= (others => '0'); 
  signal st1: std_logic_vector(2 downto 0):= (others => '0'); 
  
  signal ncmd : std_logic_vector(1 downto 0):= (others => '0');
  
  
  --UART signals
  
  signal rx_byte : std_logic_vector(7 downto 0):= (others => '0');
  signal tx_byte :std_logic_vector(7 downto 0):= (others => '0');
  
  signal TX_DONE : std_logic;
  signal tx_dv : std_logic := '0'; -- set tx to  transmit
  signal rx_dv : std_logic; -- signal recive done
  signal tx_act : std_logic; -- signal tx is transmitting
  signal TX : std_logic;
  
  type stateType is (start, recvAddr, getCmd,recvCmd, CmdOp,getSpd,recvSpd, postop);
  signal state: statetype:= start;
  
  
  constant c_CLKS_PER_BIT : integer := 10417;
 
  constant c_BIT_PERIOD : time := 104166 ns;
  
 begin 
 
--instantiate motor controller core
MC1  : motorCtrl
	port map ( 
		clk => clk,
		rst => rst,
		phaseA => pA(0),
		phaseB => pB(0),
		nCmd => ncmd(0),
		st => st0,
		sp => open,
		trig => open,
		pause => pause,
		newSpd => newspd(0),
		newCommand => newCmd(0),
		cmd => cmd
		);
MC2  : motorCtrl
	port map ( 
		clk => clk,
		rst => rst,
		phaseA => pA(1),
		phaseB => pB(1),
		nCmd => ncmd(1),
		st => st1,
		sp => open,
		trig => open,
		pause => pause,
		newSpd => newspd(1),
		newCommand => newCmd(1),
		cmd => cmd
		);	

--instantiate UART Transmitter
UART_TX_INST : uart_tx
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
      )
    port map (
      i_clk       => clk,
      i_tx_dv     => TX_DV,
      i_tx_byte   => TX_BYTE,
      o_tx_active => tx_act,
      o_tx_serial => tx,
      o_tx_done   => TX_DONE
      );
 
  -- Instantiate UART Receiver
  UART_RX_INST : uart_rx
    generic map (
      g_CLKS_PER_BIT => c_CLKS_PER_BIT
      )
    port map (
      i_clk       => clk,
      i_rx_serial => RX_in,
      o_rx_dv     => RX_DV,
      o_rx_byte   => RX_BYTE
     );

--set signals

pause <= btnl;
rst <= btnr;

D0 <= PA;
D1 <= PB;

tx_out <= tx;

led(0) <= rx_in;
led(1) <= tx;
led(3 downto 2) <= PA;
led(5 downto 4) <= PB;
led(8 downto 6) <= st0;
led(11 downto 9) <= st1;
led(13 downto 12) <= newCmd;
led(15 downto 14) <= newSpd;


--address register
process(clk,rst) begin
	if(rst = '1') then
		address <= (others => '0');
	elsif(clk'event and clk = '1') then
		if(state = recvAddr) then
			address <= rx_byte;
		end if;
	end if;
end process;

-- command register
process(clk, rst) begin
	if(rst = '1') then
		cmd <= (others => '0');
	elsif(clk'event and clk = '1') then
		if(state = recvCmd) then
			cmd <= rx_byte;
		elsif(state = recvSpd) then
			cmd <= rx_byte;
		end if;
	end if;
end process;

--speed control register
process(clk,rst) begin
	if(rst = '1') then
		speed <= (others => '0');
	elsif(clk'event and clk = '1') then
		if(state = recvSpd) then
			speed <= rx_byte;
		end if;
	end if;
end process;

--state machine

process(clk, rst) begin
	if(rst = '1') then
		state <= start;
	elsif(clk'event and clk = '1')then
		case state is
			when start => 		if(rx_dv = '1') then
										state <= recvAddr;
									end if;
									
									newCmd <= (others => '0');
									newSpd <= (others => '0');
									
			--recived an address from UART core	
			-- address will be saved, set to wait for command
			when recvAddr => 	state <= getCmd;
									
									newCmd <= (others => '0');
									newSpd <= (others => '0');
			
			--witing for uart to flag a new command
			when getCmd	=>		if(rx_dv = '1') then
										state<= recvCmd;
									end if;
									
									newCmd <= (others => '0');
									newSpd <= (others => '0');
			
			--got new command, tell correct motor controller that a new command was recived
			--if the command was a speed command further processing needs to be done.
			when recvCmd => 	newCmd(to_integer(unsigned(address))) <= '1';
									newSpd <= (others => '0');
									state <= cmdop;
									
			--state to process command, used as extra cycle to allow command to laod to register and perform any other command specific operations
			when CmdOp =>		case cmd is
										when x"03" => state <= getspd;
										when others => state <= postop;
									end case;
			--waiting for speed byte
			when getSpd => 	if(rx_dv = '1') then
										state<= recvspd;
									end if;
									newCmd <= (others => '0');
									newSpd <= (others => '0');
			
			--got speed value tell correct motor controller that it was received
			when recvSpd => 	state <= postop;
									newspd(to_integer(unsigned(address))) <= '1';
									newCmd <= (others => '0');
			
			when postop =>	 	newCmd <= (others => '0');
									newSpd <= (others => '0');
									state <= start;
		
		end case;
	end if;
end process;
end Behavioral;

