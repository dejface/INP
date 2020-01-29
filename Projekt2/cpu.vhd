-- cpu.vhd: Simple 8-bit CPU (BrainF*ck interpreter)
-- Copyright (C) 2019 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): David Oravec (xorave05)
--
 
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
 
-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic                       -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
 );
end cpu;

-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is

	-- zde dopiste potrebne deklarace signalu
	--signaly pre programovy citac
	 signal pcAddr: std_logic_vector(12 downto 0);
	 signal pcAddrInc: std_logic;
	 signal pcAddrDec: std_logic;
	 
	 --pointer PTR do casti pamati s datami
	 signal ptrAddr: std_logic_vector(12 downto 0);
	 signal ptrAddrInc: std_logic;
	 signal ptrAddrDec: std_logic;
	 
	 --signaly pre instrukciu while
	 signal cntPtr: std_logic_vector(7 downto 0);
	 signal cntPtrInc: std_logic;
	 signal cntPtrDec: std_logic;
	 
	 --multiplexory
	 signal mux1Sel: std_logic;
	 signal mux2Sel: std_logic;
	 signal mux2_out: std_logic_vector(12 downto 0);
	 signal mux3Sel: std_logic_vector(1 downto 0);
	 
	--stavy automatu
	 type fsm is (
		sIdle, sFetch, sDecode,
		sDash, sShift, sPlus, sMinus,
		sPut, sTmp, sFromTmp,
		sGet, sTmpContinue, sFromTmpContinue,
		sPlusContinue, sMinusContinue,
		sPutContinue, sInc, sGetContinue,
		sWhileStart, sInWhile1, sInWhile2, sInWhile3,
		sInWhile4, sWhileEnd0,
		sWhileEnd1, sWhileEnd2, sWhileEnd3, sWhileEnd4,
		sNull, sOthers
	 );
	 
	 signal state: fsm;
	 signal nextState: fsm;


begin

 -- zde dopiste vlastni VHDL kod


 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --   - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --   - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly.
 
	--programovy citac PC
	pcProcess: process(CLK, RESET)
	begin
		if RESET = '1' then
			pcAddr <= (others => '0');
		elsif rising_edge(CLK) then
			if pcAddrInc = '1' then
				pcAddr <= pcAddr + 1;
			elsif pcAddrDec = '1' then
				pcAddr <= pcAddr - 1;
			end if;
		end if;
	end process;
	
	--while proces
	cntProcess: process(CLK, RESET)
	begin
		if RESET = '1' then
			cntPtr <= (others => '0');
		elsif rising_edge(CLK) then
			if cntPtrInc = '1' then
				cntPtr <= cntPtr + 1;
			elsif cntPtrDec = '1' then
				cntPtr <= cntPtr - 1;
			end if;
		end if;
	end process;
	
	--ukazatel na data v pamati
	ptrProcess: process(CLK, RESET)
	begin
		if RESET = '1' then
			ptrAddr <= "1000000000000";
		elsif rising_edge(CLK) then
			if ptrAddrInc = '1' then
				if ptrAddr = "1111111111111" then
					ptrAddr <= "1000000000000";
				else
					ptrAddr <= ptrAddr + 1;
				end if;
			elsif ptrAddrDec = '1' then
				if ptrAddr = "1000000000000" then
					ptrAddr <= "1111111111111";
				else
					ptrAddr <= ptrAddr - 1;
				end if;
			end if;
		end if;
	end process;
	
	--multiplexor 1
	mux1: process(CLK, mux1Sel, pcAddr, mux2_out)
	begin
		case mux1Sel is
			when '0' => DATA_ADDR <= pcAddr;
			when '1' => DATA_ADDR <= mux2_out;
			when others =>
		end case;
	end process;
	
	--multiplexor 2
	mux2: process(CLK, mux2Sel, ptrAddr)
	begin
		case mux2Sel is
			when '0' => mux2_out <= ptrAddr;
			when '1' => mux2_out <= "1000000000000";
			when others =>
		end case;
	end process;
	
	--multiplexor 3
	mux3: process(CLK, mux3Sel, IN_DATA, DATA_RDATA)
	begin
		case mux3Sel is
			when "00" => DATA_WDATA <= IN_DATA;
			when "01" => DATA_WDATA <= DATA_RDATA - 1;
			when "10" => DATA_WDATA <= DATA_RDATA + 1;
			when "11" => DATA_WDATA <= DATA_RDATA;
			when others =>
		end case;
	end process;
	
	--aktualny stav automatu		
	fsmProcess: process(CLK, RESET)
	begin
		if RESET = '1' then
			state <= sIdle;
		elsif rising_edge(CLK) then
			if EN = '1' then
				state <= nextState;
			end if;
		end if;
	end process;
	
	--nasledujuci stav automatu
	fsmNextProcess: process(IN_VLD, OUT_BUSY, DATA_RDATA, cntPtr, state)
		
		begin 
			OUT_WE <= '0';
			IN_REQ <= '0';
			pcAddrInc <= '0';
			pcAddrDec <= '0';
			cntPtrInc <= '0';
			cntPtrDec <= '0';
			ptrAddrInc <= '0';
			ptrAddrDec <= '0';
			DATA_RDWR <= '0';
			DATA_EN <= '0';
			mux3Sel <= "00";
			
			case state is 
				
				when sIdle  =>
					nextState <= sFetch;
					
				when sFetch =>
					mux1Sel <= '0';
					DATA_EN <= '1';
					nextState <= sDecode;
					
				when sDecode =>
					mux1Sel <= '0';
					case DATA_RDATA is
						when X"3E" => nextState <= sShift;
						when X"3C" => nextState <= sDash;
						when X"2B" => nextState <= sPlus;
						when X"2D" => nextState <= sMinus;
						when X"5B" => nextState <= sWhileStart;
						when X"5D" => nextState <= sWhileEnd0;
						when X"2E" => nextState <= sPut;
						when X"2C" => nextState <= sGet;
						when X"24" => nextState <= sTmp;
						when X"21" => nextState <= sFromTmp;
						when X"00" => nextState <= sNull;
						when others => nextState <= sOthers;
						
					end case;
						
				-- pomocny stav na inkrementaciu PC, kvoli usetreniu instrukcii
				when sInc =>
					mux1Sel <= '0';
					pcAddrInc <= '1';
					nextState <= sFetch;

				-- instrukcia >
				when sShift =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					ptrAddrInc <= '1';
					nextState <= sInc;
					
				-- instrukcia <	
				when sDash =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					ptrAddrDec <= '1';
					nextState <= sInc;
				
				-- instrukcia +
				when sPlus =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sPlusContinue;
				
				when sPlusContinue =>
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mux1Sel <= '1';
					mux2Sel <= '0';
					mux3Sel <= "10";
					nextState <= sInc;
					
				-- instrukcia -
				when sMinus =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sMinusContinue;
					
				when sMinusContinue =>
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mux1Sel <= '1';
					mux2Sel <= '0';
					mux3Sel <= "01";
					nextState <= sInc;
					
				-- instrukcia .
				
				when sPut =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sPutContinue;
					
				when sPutContinue =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					if OUT_BUSY = '1' then
						nextState <= sPutContinue;
					else
						OUT_WE <= '1';
						OUT_DATA <= DATA_RDATA;
						nextState <= sInc;
					end if;
				
				--instrukcia ,					
				when sGet =>
					IN_REQ <= '1';
					nextState <= sGetContinue;
					
				when sGetContinue =>
					IN_REQ <= '1';
					if IN_VLD = '1' then 
						DATA_EN <= '1';
						DATA_RDWR <= '1';
						mux1Sel <= '1';
						mux2Sel <= '0';
						mux3Sel <= "00";
						nextState <= sInc;
					else 
						nextState <= sGetContinue;
					end if;
					
				--instrukcia $
				when sTmp =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sTmpContinue;
				
				
				when sTmpContinue =>
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mux1Sel <= '1';
					mux2Sel <= '1';
					mux3Sel <= "11";
					nextState <= sInc;
					
				--	instrukcia !
				when sFromTmp =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '1';
					nextState <= sFromTmpContinue;
				
				
				when sFromTmpContinue =>
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mux1Sel <= '1';
					mux2Sel <= '0';
					mux3Sel <= "11";
					nextState <= sInc;
				
				--instrukcia [
				when sWhileStart =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					pcAddrInc <= '1';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sInWhile1;
					
				when sInWhile1 =>
					if DATA_RDATA = X"00" then
						cntPtrInc <= '1';
						nextState <= sInWhile2;
					else 
						nextState <= sFetch;
					end if;
				
				when sInWhile2 =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '0';
					mux2Sel <= '0';
					nextState <= sInWhile3;
					
				when sInWhile3 =>
					if DATA_RDATA = X"5B" then
						cntPtrInc <= '1';
					elsif DATA_RDATA = X"5D" then
						cntPtrDec <= '1';
					end if;
					pcAddrInc <= '1';
					nextState <= sInWhile4;
					
				when sInWhile4 =>
					if cntPtr = "00000000" then
						nextState <= sFetch;
					else 
						nextState <= sInWhile2;
					end if;
				
				-- instrukcia ]
				when sWhileEnd0 =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '1';
					mux2Sel <= '0';
					nextState <= sWhileEnd1;
				
				when sWhileEnd1 =>
   				if DATA_RDATA = X"00" then
						nextState <= sInc;
					else 
						pcAddrDec <= '1';
						cntPtrInc <= '1';
						nextState <= sWhileEnd2;
					end if;
			
				when sWhileEnd2 =>
					DATA_EN <= '1';
					DATA_RDWR <= '0';
					mux1Sel <= '0';
					nextState <= sWhileEnd3;
					
				when sWhileEnd3 =>
					if DATA_RDATA = X"5B" then
						cntPtrDec <= '1';
					elsif DATA_RDATA = X"5D" then
						cntPtrInc <= '1';
					end if;
					nextState <= sWhileEnd4;
				
				when sWhileEnd4 =>
					if cntPtr = "00000000" then
						nextState <= sInc;
					else
						pcAddrDec <= '1';
						nextState <= sWhileEnd2;	
					end if;					
				
				-- null 
				when sNull =>
					nextState <= sNull;
					
				-- ostatne stavy
				when sOthers =>
					nextState <= sInc;
					
				-- hlasi error bez tohto
				when others =>
				
			end case;		
		end process;	 
end behavioral;