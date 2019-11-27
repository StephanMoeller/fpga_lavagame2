-- synthesis VHDL_INPUT_VERSION VHDL_2008 
  library IEEE;
 use IEEE.STD_LOGIC_1164.ALL;
 use IEEE.numeric_std.all;
 
 entity lavagame2 is
    Port ( 
           clk : in  std_logic; -- 50MHz input clock
           hsync : out std_logic;
			  vsync : out std_logic;
			  VGA_R : out std_logic_vector(3 downto 0);
			  VGA_G : out std_logic_vector(3 downto 0);
			  VGA_B : out std_logic_vector(3 downto 0);
			  LED : out std_logic
    );
 end lavagame2;
 
 architecture RTL of lavagame2 is
 
	 signal clk25 : std_logic; -- 25Mhx clock
	 
 begin

    -- 0 to max_count counter
    compteur : process(clk)
        
		type color_type is array (0 to 2) of natural range 0 to 255;
		type point_type is record
			x: integer;
			y: integer;
		end record point_type;
		type line_type is record
			ptA: point_type;
			ptB: point_type;
		end record line_type;
		
		variable currentColor : color_type;
		variable lightLevel : integer;
		variable PURPLE : color_type := (255,0,255);
		constant WHITE : color_type := (255,255,255);
		constant BLACK : color_type := (0,0,0);
		constant RED : color_type := (255,0,0);
		constant BLUE : color_type := (0,0,255);
		constant YELLOW : color_type := (255,255,0);
		
		constant DARK : color_type := (50,50,50);
		constant LIGHT : color_type := (255,255,255);
		
		variable ptCurrentPixel : point_type;
		variable distanceToLight : integer;
		
		type listOfWallLines_type is array (0 to 2) of line_type;
		variable listOfWallLines : listOfWallLines_type := (
			(ptA => (x => 10,y => 10), ptB => (x => 25,y => 50)),
			(ptA => (x => 100,y => 50), ptB => (x => 250,y => 50)),
			(ptA => (x => 300,y => 300), ptB => (x => 350,y => 450))
		);
		
		variable ptLight : point_type := (x => 320,y => 240);
		variable lightRadius : integer := 300;
		
		variable var_255 : integer := 255;
		variable var_100 : integer := 100;
		  
		variable lightLed : std_logic;
		
		variable counter : natural range 0 to 50000000;
		variable frameCounter : natural range 0 to 50000000;
		
		variable vga_column : natural range 0 to 1024;
		variable vga_line : natural range 0 to 1024;
		
		variable isVisible : std_logic;
		
		
		function ConvertNatural_0to255_to_4bitVector
	  (
		 inColor    : in natural range 0 to 255;
		 randomSeed    : in integer -- Used to make a softer transition between colors
	  )
		 return std_logic_vector is variable outVector : std_logic_vector(3 downto 0) := ('0', '0', '0', '0');
		 variable outputValue : natural range 0 to 15;
		 variable exceedingValue : integer;
	  begin
	   outputValue := inColor / 16; -- outputValue now ranges from 0 to 15
		exceedingValue := inColor - (outputValue * 16);
		if(exceedingValue > 0 and outputValue < 15) -- 'exceedingValue > 0' to avoid modulus with 0, 'outputValue < 15' to avoid overflow
		then
			if(randomSeed mod 16 < exceedingValue)
			then
				outputValue := outputValue + 1;
			end if;
		end if;
		
		-- determine how much was lost in the division. the more value lost, the higher chance it has to get +1 on outputValue
		if((outputValue/1) mod 2 = 1) then outVector(0) := '1'; end if;
		if((outputValue/2) mod 2 = 1) then outVector(1) := '1'; end if;
		if((outputValue/4) mod 2 = 1) then outVector(2) := '1'; end if;
		if((outputValue/8) mod 2 = 1) then outVector(3) := '1'; end if;
		
		return outVector;
	  end function ConvertNatural_0to255_to_4bitVector;
		
		/*
			Following functions are direct conversion of this line intersect functions from java: https://www.geeksforgeeks.org/check-if-two-given-line-segments-intersect/
		*/
		function max
		(
			v1 : in integer;
			v2 : in integer
		)
		return integer is variable highestValue : integer;
		begin
			if(v1 > v2)
			then
				highestValue := v1;
			else
				highestValue := v2;
			end if;
			
			return highestValue;
		end function max;
		
		function min
		(
			v1 : in integer;
			v2 : in integer
		)
		return integer is variable highestValue : integer;
		begin
			if(v1 < v2)
			then
				highestValue := v1;
			else
				highestValue := v2;
			end if;
			
			return highestValue;
		end function min;
		
    begin
	   -- start of rising
      if rising_edge(clk) then
		  
			-- LED COUNTER LOGIC
			counter := counter + 1;
			if (counter >= 50000000)
			then
				lightLed := not lightLed;
				counter := 0;
			end if;
	
			-- Start of 25Mhz clause
			clk25 <= not clk25;
			if(clk25 = '1')
			then
				
				-- VGA: Counters ++
				if (vga_column < 799)
				then
						vga_column := vga_column + 1;
				else
					vga_column := 0;
					if (vga_line < 524)
					then
						vga_line := vga_line + 1;
					else
						vga_line := 0;
					end if;
				end if;
				if(vga_column < 640 and vga_line < 480) then isVisible := '1'; else isVisible := '0'; end if;
				
				-- LOGIC:
				ptCurrentPixel := (x => vga_column,y => vga_line);
				
				-- Decide light level based on distance to light
				distanceToLight := ((ptCurrentPixel.x - ptLight.x)**2 + (ptCurrentPixel.y - ptLight.y)**2);
				if(distanceToLight < lightRadius*lightRadius)
				then
					-- Within radius of the light
					lightLevel := ((distanceToLight * 255) / (lightRadius*lightRadius));
					if(lightLevel >= 0 and lightLevel <= 255)
					then
						currentColor := (lightLevel,lightLevel,lightLevel);
					else
						currentColor := RED; -- sanity testing that this is not hit
					end if;
					
				else
					currentColor := BLACK;
				end if;
				
				
				-- VGA: HSYNC and VSYNC
				if(vga_column < (640 + 16) or vga_column >= (640 + 16 + 96))
					then hsync <= '1';
					else hsync <= '0';
				end if;
			
				if(vga_line < (480 + 10) or vga_line >= (480 + 10 + 2))
					then vsync <= '1';
					else vsync <= '0';
				end if; 
				
				-- VGA: RGB on current pixel
				if(isVisible = '1')
				then
					VGA_R <= ConvertNatural_0to255_to_4bitVector(currentColor(0), ptCurrentPixel.x+ptCurrentPixel.y);
					VGA_G <= ConvertNatural_0to255_to_4bitVector(currentColor(1), ptCurrentPixel.x+ptCurrentPixel.y);
					VGA_B <= ConvertNatural_0to255_to_4bitVector(currentColor(2), ptCurrentPixel.x+ptCurrentPixel.y);
				else
					VGA_R <= ('0','0','0','0');
					VGA_G <= ('0','0','0','0');
					VGA_B <= ('0','0','0','0');
				end if;
				
				
			end if; -- end of 25Mhx clause
			
		end if; -- ENd of rising clause
		
		
		
		LED <= lightLed;
		
    end process compteur; 
 end RTL;