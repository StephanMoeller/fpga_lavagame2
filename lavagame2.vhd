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
		variable PURPLE : color_type := (255,0,255);
		constant WHITE : color_type := (255,255,255);
		constant BLACK : color_type := (0,0,0);
		constant RED : color_type := (255,0,0);
		constant BLUE : color_type := (0,0,255);
		
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
		
		variable ptLight : point_type := (x => 500,y => 150);
		  
		variable lightLed : std_logic;
		
		
		variable counter : natural range 0 to 50000000;
		variable frameCounter : natural range 0 to 50000000;
		
		variable vga_column : natural range 0 to 1024;
		variable vga_line : natural range 0 to 1024;
		
		variable isVisible : std_logic;
		
		
		function GetBackgroundColor
		()
		
		
		function DecideColorFromDistance
	  (
		 distance    : in integer
	  )
		 return color_type is variable outColor : color_type;
		 variable lightLevel : integer;
	  begin
		lightLevel := distance * 255 / ((640*640)+(480*480));
		 lightLevel := ((640*640)+(480*480)) - lightLevel;
		 outColor := (lightLevel,lightLevel,lightLevel);
		return outColor;
	  end function DecideColorFromDistance;
		
		function ConvertNatural_0to255_to_4bitVector
	  (
		 inColor    : in natural range 0 to 255;
		 randomSeed    : in integer -- Used to make a softer transition between colors
	  )
		 return std_logic_vector is variable outVector : std_logic_vector(3 downto 0) := ('0', '0', '0', '0');
		 variable outputValue : natural range 0 to 15;
	  begin
		outputValue := inColor / 16; -- outputValue now ranges from 0 to 15
		if(inColor - outputValue*16 > 0 and outputValue < 15) -- <= FIX THIS BUG: When inColor = 1, this resolves to 1, going in, randomSeed mod 1 is always 0, hence, outputValue is subtracted with 1 making it overflow and end up as 15
		then
			-- Values from 1-14 here:
			if (randomSeed mod (inColor - outputValue*16) > 0)
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
		This functions returns true if point and line collide
		*/
	  function CheckPointOnLine
	  (
		 inPoint    : in point_type;
		 inLine 	 : in line_type
	  )
		 return std_logic is variable collision : std_logic := '0';
		 variable percentage : integer;
		 variable expectedY : integer;
	  begin
		 if(inPoint.x < inLine.ptA.x and inPoint.x < inLine.ptB.x) then collision := '0';  -- point is to the left
		 elsif(inPoint.x > inLine.ptA.x and inPoint.x > inLine.ptB.x) then collision := '0'; -- point is to the right
		 elsif(inPoint.y < inLine.ptA.y and inPoint.y < inLine.ptB.y) then collision := '0'; -- point is above
		 elsif(inPoint.y > inLine.ptA.y and inPoint.y > inLine.ptB.y) then collision := '0';
		 else
			-- Point is within the square of the line
			percentage := ((inPoint.x - inLine.ptA.x) * 100 / (inLine.ptB.x - inLine.ptA.x));
			expectedY := inLine.ptA.y + ((inLine.ptB.y - inLine.ptA.y) * percentage / 100);
			if (expectedY = inPoint.y or expectedY = -inPoint.y)
			then
				collision := '1';
			else
				collision := '0';
			end if;
		 end if; -- point is below
		 
		 return collision;
	  end function CheckPointOnLine;
		
		
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
		
		/*
		// Given three colinear points p, q, r, the function checks if 
		// point q lies on line segment 'pr' 
		bool onSegment(Point p, Point q, Point r) 
		{ 
			 if (q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) && 
				  q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y)) 
				 return true; 
		  
			 return false; 
		} 
		*/
		function onSegment
		(
			p    : in point_type;
			q    : in point_type;
			r    : in point_type
		)
		return std_logic is variable isOnSegment : std_logic := '0';
		begin
			if (q.x <= max(p.x, r.x) and q.x >= min(p.x, r.x)
			and q.y <= max(p.y, r.y) and q.y >= min(p.y, r.y))
				then
					isOnSegment := '1';
				else
					isOnSegment := '0';
				end if;
				return isOnSegment;
		end function onSegment;
		
		/*
		// To find orientation of ordered triplet (p, q, r). 
		// The function returns following values 
		// 0 --> p, q and r are colinear 
		// 1 --> Clockwise 
		// 2 --> Counterclockwise 
		int orientation(Point p, Point q, Point r) 
		{ 
			 // See https://www.geeksforgeeks.org/orientation-3-ordered-points/ 
			 // for details of below formula. 
			 int val = (q.y - p.y) * (r.x - q.x) - 
						  (q.x - p.x) * (r.y - q.y); 
		  
			 if (val == 0) return 0;  // colinear 
		  
			 return (val > 0)? 1: 2; // clock or counterclock wise 
		} 
		*/
		function orientation
		(
			p    : in point_type;
			q    : in point_type;
			r    : in point_type
		)
		return integer is variable outOrientation : integer;
		variable tmpVal : integer;
		begin
		
			tmpVal := (q.y - p.y) * (r.x - q.x) - 
						  (q.x - p.x) * (r.y - q.y); 
		  
			 if (tmpVal = 0)
			 then
				outOrientation := 0;
			 elsif (tmpVal > 0)
			 then
				outOrientation := 1;
			 else
				outOrientation := 2;
			 end if;
		
			return outOrientation;
		end function orientation;
		
		/*
		// The main function that returns true if line segment 'p1q1' 
		// and 'p2q2' intersect. 
		bool doIntersect(Point p1, Point q1, Point p2, Point q2) 
		{ 
			 // Find the four orientations needed for general and 
			 // special cases 
			 int o1 = orientation(p1, q1, p2); 
			 int o2 = orientation(p1, q1, q2); 
			 int o3 = orientation(p2, q2, p1); 
			 int o4 = orientation(p2, q2, q1); 
		  
			 // General case 
			 if (o1 != o2 && o3 != o4) 
				  return true; 
		  
			 // Special Cases 
			 // p1, q1 and p2 are colinear and p2 lies on segment p1q1 
			 if (o1 == 0 && onSegment(p1, p2, q1)) return true; 
		  
			 // p1, q1 and q2 are colinear and q2 lies on segment p1q1 
			 if (o2 == 0 && onSegment(p1, q2, q1)) return true; 
		  
			 // p2, q2 and p1 are colinear and p1 lies on segment p2q2 
			 if (o3 == 0 && onSegment(p2, p1, q2)) return true; 
		  
			  // p2, q2 and q1 are colinear and q1 lies on segment p2q2 
			 if (o4 == 0 && onSegment(p2, q1, q2)) return true; 
		  
			 return false; // Doesn't fall in any of the above cases 
		} 
		*/
		function doIntersect
		(
			p1 : point_type;
			q1 : point_type;
			p2 : point_type;
			q2 : point_type
		)
		return std_logic is variable outVal : std_logic := '0';
		variable o1 : integer;
		variable o2 : integer;
		variable o3 : integer;
		variable o4 : integer;
		begin
		
			o1 := orientation(p1, q1, p2); 
			o2 := orientation(p1, q1, q2); 
			o3 := orientation(p2, q2, p1); 
			o4 := orientation(p2, q2, q1); 
		
			if (o1 /= o2 and o3 /= o4) then outVal := '1';
			elsif (o1 = 0 and onSegment(p1, p2, q1) = '1') then outVal := '1';
			elsif (o2 = 0 and onSegment(p1, q2, q1) = '1') then outVal := '1';
			elsif (o3 = 0 and onSegment(p2, p1, q2) = '1') then outVal := '1';
			elsif (o4 = 0 and onSegment(p2, q1, q2) = '1') then outVal := '1';
			else
				outVal := '0';
			end if;
		
			return outVal;
		end function doIntersect;
		
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
				
				
				/*
VGA theory taken from: http://martin.hinner.info/vga/640x480_60.html
Essentials (adjusted to start with video area):

One line
640 pixels video
  8 pixels right border
  8 pixels front porch
 96 pixels horizontal sync
 40 pixels back porch
  8 pixels left border

---
800 pixels total per line

One field
480 lines video
  8 lines bottom border
  2 lines front porch
  2 lines vertical sync
 25 lines back porch
  8 lines top border

---
525 lines total per field   

*/
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
				
				-- light movement
				if(ptCurrentPixel.x = 0 and ptCurrentPixel.y = 0)
				then
					frameCounter := frameCounter + 1;
					ptLight.x := ptLight.x + 1;
					if(ptLight.x > 640)
					then
						ptLight.x := 0;
					end if;
				end if;
				
				-- LOGIC:
				ptCurrentPixel := (x => vga_column,y => vga_line);
				
				-- Distance goes from 0 to about 63:
				distanceToLight := ((ptCurrentPixel.x - ptLight.x)*(ptCurrentPixel.x - ptLight.x) + (ptCurrentPixel.y - ptLight.y)*(ptCurrentPixel.y - ptLight.y));
				counter := counter + distanceToLight;
				currentColor := DecideColorFromDistance(distanceToLight);
				
				-- draw light/shadow
				for I in 0 to 2 loop
					if (doIntersect(ptCurrentPixel, ptLight, listOfWallLines(I).ptA, listOfWallLines(I).ptB) = '1')
					then
						currentColor := BLACK;
					end if;
				end loop; 
				
				-- Draw walls
				for I in 0 to 2 loop
					-- If pixel is on a wall - paint wall
					if( CheckPointOnLine(ptCurrentPixel, listOfWallLines(I)) = '1')
					then
						currentColor := RED;
					end if;
				end loop;
					
				
				-- DRAW LIGHT dot
				if(ptCurrentPixel.x = ptLight.x and ptCurrentPixel.y = ptLight.y)
				then
					currentColor := BLUE;
				end if;
				
				
				
				-- DRAW BORDER
				if(ptCurrentPixel.x = 0 or ptCurrentPixel.x = 638 or ptCurrentPixel.y = 1 or ptCurrentPixel.y = 479)
				then
					-- BORDER 
					currentColor := PURPLE;
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
					VGA_R <= ConvertNatural_0to255_to_4bitVector(currentColor(0), ptCurrentPixel.x+ptCurrentPixel.y*3+counter);
					VGA_G <= ConvertNatural_0to255_to_4bitVector(currentColor(1), ptCurrentPixel.x+ptCurrentPixel.y*3+counter);
					VGA_B <= ConvertNatural_0to255_to_4bitVector(currentColor(2), ptCurrentPixel.x+ptCurrentPixel.y*3+counter);
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