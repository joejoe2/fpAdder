module fpadder(src1, src2,out);
input [31:0] src1, src2;
output [31:0] out;

reg           sumsign;
reg [7:0]    sumexp;
reg [22+3:0]    summatissa;
reg [31:0] f1,f2;
reg [22+3:0]    matissa1, matissa2;
reg [7:0]    exp1, exp2;
reg           s1, s2;
reg [7:0]    dif;
reg g,r,s;
reg [2:0] m1,m2;
reg [22+3+3:0] t;

reg [31:0] out;

always @( src1 or src2 )begin

/// Compute IEEE 754 Double Floating-Point Sum in Seven Easy Steps
/// Step 1: Copy inputs to f1 and f2 so that f1's exponent not smaller than f2's.
//
if ( src1[30:23] <= src2[30:23] ) begin
f1 = src2;  f2 = src1;
end
else begin
f1 = src1;  f2 = src2;
end

/// Step 2: Break operand into sign (neg), exponent, and matissa.
//
s1 = f1[31];     s2 = f2[31];
exp1 = f1[30:23];  exp2 = f2[30:23];
// Put f1 0 in bits 24 and 25 (later used for sign).
// Put f1 1 in bit 23 of matissa if exponent is non-zero.
// Copy matissa into remaining bits.
matissa1 = { 2'b00, exp1 ? 1'b1 : 1'b0, f1[22:0] };
matissa2 = { 2'b00, exp2 ? 1'b1 : 1'b0, f2[22:0] };

/// Step 3: Un-normalize f2 so that exp1 == exp2.
//
begin:A

integer i;
dif = exp1 - exp2;
if(exp2==0&&exp1!=0)dif=dif-1;
g=0;r=0;s=0;t=0;
for(i=30;i>0;i=i-1)begin//shift must < 30 bit
    if((30-i)<dif)begin
    s=s|r;
	 r=g;
	 g=matissa2[0];
    matissa2 = matissa2 >> 1;
	 end
end

//matissa2 = matissa2 >> dif;
end
//
// Note: exp2 no longer used. If it were would need to set exp2 = exp1;

/// Step 4: If necessary, negate matissa.
//
/// Step 5: Compute sum.
//

if ( s1 ) {matissa1,m1} = -{matissa1,3'b000};
if ( s2 ) {matissa2,g,r,s} = -{matissa2,g,r,s};

{summatissa,g,r,s} = {matissa1,m1} + {matissa2,g,r,s};
/// Step 6: Take absolute value of sum.
//
sumsign = summatissa[22+3];
if ( sumsign ) {summatissa,g,r,s} = -{summatissa,g,r,s};
//$write("%b\n",summatissa);
/// Step 7: Normalize sum. (Three cases.)
//

if (summatissa[22+3-1]) begin
//
// Case 1: Sum overflow.
//         Right shift sum and increment exponent.
//$write("case1:\n");
sumexp = exp1 + 1;
s=s|r;
r=g;
g=summatissa[0];
summatissa = summatissa >> 1;

//
if(({g,r,s}==3'b101||{g,r,s}==3'b110||{g,r,s}==3'b111)||({g,r,s}==3'b100&&summatissa[0]==1))begin
   summatissa = summatissa +1;
	if ( summatissa[22+3-1] ) begin
   sumexp = sumexp + 1;
   summatissa = summatissa >> 1;
   end

end
//
end 
else if ( {summatissa,g,r,s} ) begin:B
//
// Case 2: Sum is nonzero and did not overflow.
//         Normalize. (See cases 2a and 2b.)

integer pos, adj, i,c;
c=1;
// Find position of first non-zero digit.
pos = 0;
for (i = 23+3; i >= 0; i = i - 1 ) begin
t={summatissa,g,r,s};
   if ( !pos && t[i]&&c ) begin
   pos = i;c=0;
	end
end
// Compute amount to shift sum and reduce exponent.
adj = 23+3 - pos;//$write("%3d\n",adj);
if ( exp1 < adj ||exp1==0) begin
//$write("case2a:\n");
//
// Case 2a:
//   Exponent too small.
{summatissa,g,r,s}={summatissa,g,r,s}<<exp1;//$write("2a");
sumexp = 0;
 if(summatissa[23])sumexp = 1;
  if(({g,r,s}==3'b101||{g,r,s}==3'b110||{g,r,s}==3'b111)||({g,r,s}==3'b100&&summatissa[0]==1))begin
   summatissa = summatissa +1;
	if ( summatissa[22+3-1] ) begin
   sumexp = sumexp + 1;
   summatissa = summatissa >> 1;
   end
	else if(summatissa[23]&&sumexp == 0)begin
	  sumexp = 1;
	end
  end
//summatissa = 0;
//sumsign = 0;
end else begin
//
// Case 2b: Adjust sum and exponent.
//
//$write("case2b:\n");
sumexp = exp1 - adj;//$write("%b\n",{{sumsign,sumexp,summatissa[22:0]}});
for(i=23+3;i>0&&sumexp!=0;i=i-1)begin
   if((23+3-i)<adj)begin
   {summatissa,g,r,s} = {summatissa,g,r,s} <<1;
	//summatissa[0]=g;
	//g=r;
	//r=s;
	//s=s&0;
	end
end
//
//$write("%b\n",{{sumsign,sumexp,summatissa[22:0]}});
//summatissa = summatissa << adj;
//
if(({g,r,s}==3'b101||{g,r,s}==3'b110||{g,r,s}==3'b111)||({g,r,s}==3'b100&&summatissa[0]==1))begin
   summatissa = summatissa +1;
	if ( summatissa[22+3-1] ) begin
   sumexp =sumexp + 1;
   summatissa = summatissa >> 1;
   end
   //$write("%b\n",{sumsign,sumexp,summatissa[22:0]});
end
//
end
end else begin
//
// Case 3: Sum is zero.
//$write("%b\n",{summatissa,g,r,s});
//$write("case3:\n");
sumexp = 0;
summatissa = 0;
sumsign=0;
end


if(sumexp<255)begin
out[31]= sumsign;
out[30:23]= sumexp;
out[22:0]= summatissa;
end
else if(sumexp==255&&summatissa!=0)begin
out[31]= sumsign;
out[30:23]= sumexp;
out[22:0]= 0;
end


//$write("%32b+%32b=%8h\n",src1,src2,out);

end



endmodule
