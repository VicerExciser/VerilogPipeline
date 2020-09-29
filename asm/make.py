import os
import sys

file = sys.argv[1]
if '.asm' in file:
	file = file[:-4]
ret = os.getcwd()
path = ret[:-4]
os.chdir(path)
if os.path.isfile(file+'.mif'):
	os.system('rm {}.mif'.format(file))
if os.path.isfile(file+'.hex'):
	os.system('rm {}.hex'.format(file))
os.chdir(ret)
os.system('python assembler.py {}.asm'.format(file))
os.system('python miftohex.py {}.mif'.format(file))
os.system('mv {}.mif .. && mv {}.hex ..'.format(file,file))
