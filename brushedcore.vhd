library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity motorCtrl is
	
	port(
	
	clk: IN std_logic;
	--sw: in std_logic_vector(7 downto 0)

	rst : in std_logic;
	
	phaseA : out std_logic;
	phaseB : out std_Logic;
	
	ncmd: out std_logic;
	
	st : out std_logic_vector(2 downto 0) := "000";
	
	
	trig : out std_logic;
	sp : out std_logic_vector(7 downto 0);
	
	pause : in std_logic;
	
	newSpd : in std_logic; --flag for new speed value
	newCommand : in std_logic; --flag for new command 
	cmd : in std_logic_vector(7 Downto 0) --command Byte, also used for 8 bit speed value
	
	);
	
end motorCtrl;

architecture Behavioral of motorCtrl is

	signal trigger : std_logic := '0';
	signal counter : std_logic_vector(15 downto 0):= (others => '0');
	
	
	signal counttrig : std_logic_vector(15 downto 0):= (others => '0'); -- value that the counter will count down to for trigger set
	
	signal newcmd : std_logic := '0'; 
	signal cmdFlg : std_logic := '0';--flag for new command
	
	signal speedCtrl : std_logic_vector(7 downto 0) := (others => '0'); 
	signal setSpeed : std_logic := '0'; -- flag for state machine
	signal setSpeedFlg : std_logic := '0'; -- flag for edge case
	
	signal inc : std_logic:='0';
	
	signal fwd : std_logic:= '1'; --if 1 motor controller will go forward, if 0 will go backward
	
	type stateType is (start, rcvCmd, sSpeed,frwd, bck, stop, incDec);
	signal state: stateType := start;
	

begin

trig <= trigger;

sp <= speedCtrl;


-- counter logic
process(rst,clk) begin
	if(rst = '1') then
		counter <= (others => '0');
	end if;
	if (clk'EVENT and clk = '1')then
		counter <= counter + '1'; 
	end if;
end process;

--command register
--process(rst, clk)begin
--	if(rst = '1') then
--		command <= (others => '0');
--	elsif (clk'event and clk = '1') then
--		if(newCmd = '1') then
--			command <= cmd;
--		end if;
--	end if;
--end process;

--speed register
ncmd <= newCmd;

--flag to deal with edge case involving setting a new speed, makes sure a new command cant be misnterperited as a speed
process (newSpd, clk) begin
	if(clk'event and clk = '1') then
		if(newSpd = '1') then
			if(setSpeedFlg = '0') then
				setSpeed <= '1';
				setspeedFlg <='1';
			else
				setSpeed <= '0';
			end if;
		elsif(newSpd = '0') then
			setSpeedFlg <= '0';
			setSpeed <= '0';
		end if;
	end if;
end process;

--flag to deal with edge case if new command is held high for too long
process (newCommand, clk) begin
	if(clk'event and clk = '1') then
		if(newCommand = '1') then
			if(cmdflg = '0') then
				newCmd <= '1';
				cmdflg <='1';
			else
				newCmd <= '0';
			end if;
		elsif(newcommand = '0') then
			cmdflg <= '0';
			newCmd <='0';
		end if;
	end if;
end process;


--speed control register

process(rst, clk) begin
	if(rst = '1')then
		speedCtrl <= (others => '0');
	end if;
	if(clk'event and clk = '1') then
		if(state = sSpeed and setSpeed = '1') then
			speedCtrl <= cmd;
		elsif(state = incDec) then
			if(inc = '0') then
				if(speedCtrl = x"0000") then
					speedCtrl <= speedCtrl;
				else
					speedCtrl <= speedCtrl - '1';
				end if;
			elsif(inc = '1') then 
				if(speedCtrl = x"ffff") then
					speedCtrl <= speedCtrl;
				else
					speedCtrl <= speedCtrl +'1';
				end if;
			end if;
		end if;
	end if;
end process;
	
--output pwm duty cycle selection

--use clock dividing to get decent spread of values
--counts down from 2^32 until the counttrig value, MSB set by speedCtrl, 
counttrig(15 downto 8) <= speedCtrl;
counttrig(7 downto 0) <= x"00";

--while the counter is higher than the counttrig output value is low, when counter is lower than counttrig value output is high
process(clk,rst) begin
	
	if(clk'event and clk = '1') then
		if(rst = '1') then
			trigger <= '0';
	-- to eliminate jitter at speedvalue 0 set output to 0 when speedCtrl is 0
		elsif(speedCtrl = x"0000") then
			trigger <= '0';
		elsif (counttrig >= counter) then
			trigger <= '1';
		elsif( counttrig < counter) then
			trigger <= '0';
		else
			trigger <= '0';
		end if;
	end if;
end process;


--state flag logic


--state Machine
process(clk,rst,pause) begin
	if(rst = '1') then
		state <= start;
		st <= "000";
	end if;
	if(clk'event and clk = '1') then
		case state is
			when start => 	phaseA <= '0';
								phaseB <= '0';
								st <= "000";
								
								if(newCmd = '1') then 
									state <= rcvCmd;
								else 
									state <= start;
								end if;
								
			when rcvCmd =>	phaseA <= '0';
								phaseB <= '0';
								st <= "001";
								
								case cmd is
									--stop command 0x00
									when x"00" => state <= start;

									--forward command 0x01
									when x"01" => state <= frwd;
									--reverse command 0x02
									when x"02" => state <= bck;
									
									--set speed command 0x03
									when x"03" => state <= sSpeed;
									--increment speed command 0x04
									when x"04" => 	inc <= '1';
														state <= incdec;
									--decrement speed command 0x05
									when x"05" => 	inc <= '0';
														state <= incdec;
														
									when others => state <= start;
								end case;
								
			when sSpeed => 	phaseA <= '0';
									phaseB <= '0';
									st <= "010";
									
									if(setSpeed = '1') then
										if(pause = '1')	then
											state <= stop;
										elsif (fwd = '1') then 
											state <= frwd;
										elsif (fwd = '0') then 
											state <= bck;
										end if;
									end if;
										

			when frwd => 	phaseA <= trigger;
								phaseB <= '0';
								st <= "011";
								
								fwd <= '1';
								if(pause  = '1') then
									state <= stop;
								elsif(newCmd <= '0') then 
									state <= frwd;
								elsif(newCmd <= '1') then
									state <= rcvCmd;
								end if;
							
							
			when bck =>		phaseA <= '0';
								phaseB <= trigger;
								st<= "100";
								
								fwd <= '0';
								
								if(pause  = '1') then
									state <= stop;
								elsif(newCmd <= '0') then 
									state <= bck;
								elsif(newCmd <= '1') then
									state <= rcvCmd;
								end if;
			
			when stop =>	phaseA <= '0';
								phaseB <= '0';
								st <= "101";
								
								--if pause ends check if there is a new comand else resume in same direction
								if(pause = '0') then 
									if(newCmd ='1') then
										state <= rcvCmd;
									elsif (fwd = '1') then 
										state <= frwd;
									elsif (fwd = '0') then 
										state <= bck;

									end if;
								end if;
								
			when incdec => phaseA <= '0';
								phaseB <= '0';
									
								if(pause = '1')	then
									state <= stop;
								elsif (fwd = '1') then 
									state <= frwd;
								elsif (fwd = '0') then 
									state <= bck;
								end if;
								st <= "110";
		end case;
	end if;
end process;

end Behavioral;