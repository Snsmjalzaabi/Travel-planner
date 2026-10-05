
import struct, zlib, os
out=os.environ.get("OUT","/tmp/icon")
os.makedirs(out, exist_ok=True)
def b8(i): return bytes([i&255])
def png(w,h,chunks):
    def chunk(t,typ,data):
        c=typ+d3(data); d3=d3
        return b8(len(data))+d3+typ+data+d3(check(data))
    ...
