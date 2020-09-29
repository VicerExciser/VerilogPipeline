# def divhex(x):
# ...     x = x[2:] if '0x' in x else x
# ...     ndig = len(x)                
# ...     for i in range(ndig):                
# ...             val = hex((int(x,16) & ((int('0xf',16) << (4 + 4*i))))
# ...             print(val)

import sys

sx = sys.argv[1]
x = sx[2:] if '0x' in sx else sx
ndig = len(x)                
for i in range(ndig):        
	shift = 4*(ndig-(i+1))        
	mask = 0xf << shift
	val = hex((int(x,16) & mask) >> shift)
	print(val)
