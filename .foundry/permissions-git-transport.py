#!/usr/bin/env python3
import os,sys
args=sys.argv[1:]
root='/tmp/starter-c8-permissions/bedrock'
if len(args)>2 and args[0]=='-C' and args[1]==root:
    if args[2] not in ('remote','rev-parse','show','archive','status','log'): raise SystemExit('Forbidden archive Git write')
    args[1]='/home/svetzal/Work/Projects/Mojility/bedrock'
pins={'bedrock': '78767528c45c0d9412c4cbc90d395c724ed1c5ee', 'roost': 'bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8', 'bedrock-workshop': '32730f7132b1a262b85a0b66fcc46fedd1b8051a'}
if len(args)>2 and args[0]=='-C':
    name=os.path.basename(args[1])
    if name in pins:
        args=[pins[name] if a=='HEAD' else a for a in args]
os.execv('/usr/bin/git',['git',*args])
