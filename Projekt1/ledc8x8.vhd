-- Autor reseni: David Oravec (xorave05)

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity ledc8x8 is
port ( 
RESET, SMCLK: in std_logic;	-- asynchronna inicializacia hodnot a hlavny hodinovy signal
ROW, LED: out std_logic_vector(0 to 7)	-- signal pre vyber riadku a stlpca
);
end ledc8x8;

architecture main of ledc8x8 is

    signal clock_enable: std_logic := '0';	-- povolovaci sinal
    signal clock_enable_count: std_logic_vector (0 to 11) := (others => '0');	--7372800/256/8 = 111000010000 binarne, tj 12bitov
    signal state_count: std_logic_vector(0 to 21) := (others => '0');	--nulovanie stavu .. 7372800/2 bin 
    signal state: std_logic_vector(0 to 1) := "00";	--signal ktory zaistuje zmenu stavu svietenia a zhasnutia
    signal rows: std_logic_vector(0 to 7) := "10000000";	--signal pre riadky, zacina na prvom riadku 100000000
    signal leds: std_logic_vector(0 to 7) := "11111111";	--LED signal, na zaciatku su neaktivne

begin
	-- 1. citac zaistuje clock_enable
	process(SMCLK, RESET)
	begin 
		if RESET = '1' then
			clock_enable_count <= (others => '0');
		elsif rising_edge(SMCLK) then
			clock_enable_count <= clock_enable_count + 1;
			if clock_enable_count = "111000010000" then
				clock_enable <= '1';
			else
				clock_enable <= '0';
			end if;
		else
		end if;
	end process;
	--2. citac zaistuje za 1 sekundu zmenu stavu po pol sekunde zo svietenia na zhasnutie
	process(SMCLK,state)
	begin
		if rising_edge(SMCLK) then
			state_count <= state_count + 1;
			if state_count = "1110000100000000000000" then	--cislo frekvencie s ktorou sa stav meni
				if (state = "10") then
				else
					state <= state +1;
				end if;	
				state_count <= (others => '0');	--nulovanie vnutorneho signalu citaca
			else
			end if;
		else
		end if;
	end process;

	--zmena aktivity riadku
	process(RESET, clock_enable)
	begin
		if RESET = '1' then
			rows <= "10000000";
		elsif rising_edge(clock_enable) then
			rows <= rows(7) & rows(0 to 6);	--posuvanie 0 z prava do lava kvoli pokrytiu vsetkych riadkov
		else
		end if;
	end process;
	--dekoder na prepinanie lediek
	process(rows, state)
	begin
		if (state = "00") then
			case rows is
				when "10000000" => leds <= "10001111";
              			when "01000000" => leds <= "10110111";
              			when "00100000" => leds <= "10110111";
              			when "00010000" => leds <= "10110111";
              			when "00001000" => leds <= "10001000";
              			when "00000100" => leds <= "11111010";
              			when "00000010" => leds <= "11111010";
              			when "00000001" => leds <= "11111000";
              			when others     => leds <= "11111111";
			end case;
		elsif (state = "01") then
			case rows is
				when "10000000" => leds <= "11111111";
              			when "01000000" => leds <= "11111111";
              			when "00100000" => leds <= "11111111";
              			when "00010000" => leds <= "11111111";
              			when "00001000" => leds <= "11111111";
              			when "00000100" => leds <= "11111111";
              			when "00000010" => leds <= "11111111";
              			when "00000001" => leds <= "11111111";
              			when others     => leds <= "11111111";
			end case;
		elsif (state = "10") then
			case rows is
				when "10000000" => leds <= "10001111";
              			when "01000000" => leds <= "10110111";
              			when "00100000" => leds <= "10110111";
              			when "00010000" => leds <= "10110111";
              			when "00001000" => leds <= "10001000";
              			when "00000100" => leds <= "11111010";
              			when "00000010" => leds <= "11111010";
              			when "00000001" => leds <= "11111000";
              			when others     => leds <= "11111111";
			end case;
		elsif (state = "11") then
			case rows is
				when "10000000" => leds <= "10001111";
              			when "01000000" => leds <= "10110111";
              			when "00100000" => leds <= "10110111";
              			when "00010000" => leds <= "10110111";
              			when "00001000" => leds <= "10001000";
              			when "00000100" => leds <= "11111010";
              			when "00000010" => leds <= "11111010";
              			when "00000001" => leds <= "11111000";
              			when others     => leds <= "11111111";
			end case;
		else 
			case rows is
				when "10000000" => leds <= "10001111";
              			when "01000000" => leds <= "10110111";
              			when "00100000" => leds <= "10110111";
              			when "00010000" => leds <= "10110111";
              			when "00001000" => leds <= "10001000";
              			when "00000100" => leds <= "11111010";
              			when "00000010" => leds <= "11111010";
              			when "00000001" => leds <= "11111000";
              			when others     => leds <= "11111111";
			end case;
		end if;
	end process;
	ROW <= rows;
	LED <= leds;
end architecture main;





-- ISID: 75579
