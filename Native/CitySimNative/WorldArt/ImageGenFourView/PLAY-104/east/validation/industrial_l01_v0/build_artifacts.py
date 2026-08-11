#!/usr/bin/env python3
"""Deterministic, repository-local normalization and contact-sheet builder."""
from __future__ import annotations
import struct, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[8]
EAST = ROOT / "Native/CitySimNative/WorldArt/ImageGenFourView/PLAY-104/east"
RAW = EAST / "raw/industrial_l01_v0/east-source-v01.png"
OUT = EAST / "lod/industrial_l01_v0"
SHEETS = EAST / "contact-sheets"
SIG = b"\x89PNG\r\n\x1a\n"

def paeth(a,b,c):
    p=a+b-c; pa,pb,pc=abs(p-a),abs(p-b),abs(p-c)
    return a if pa<=pb and pa<=pc else (b if pb<=pc else c)

def decode(path):
    raw=path.read_bytes(); off=len(SIG); idat=bytearray(); width=height=typ=None
    while off<len(raw):
        n=struct.unpack(">I",raw[off:off+4])[0]; kind=raw[off+4:off+8]; data=raw[off+8:off+8+n]
        if kind==b"IHDR": width,height,depth,typ,comp,filt,inter=struct.unpack(">IIBBBBB",data)
        elif kind==b"IDAT": idat.extend(data)
        elif kind==b"IEND": break
        off += n+12
    channels=3 if typ==2 else 4; scan=zlib.decompress(idat); stride=width*channels; out=bytearray(height*stride); pos=0
    for y in range(height):
        ft=scan[pos]; pos+=1; row=bytearray(scan[pos:pos+stride]); pos+=stride; prev=out[(y-1)*stride:y*stride] if y else bytes(stride)
        for x in range(stride):
            left=row[x-channels] if x>=channels else 0; up=prev[x]; ul=prev[x-channels] if x>=channels else 0
            if ft==1: row[x]=(row[x]+left)&255
            elif ft==2: row[x]=(row[x]+up)&255
            elif ft==3: row[x]=(row[x]+(left+up)//2)&255
            elif ft==4: row[x]=(row[x]+paeth(left,up,ul))&255
        out[y*stride:(y+1)*stride]=row
    return width,height,channels,bytes(out)

def write(path,w,h,channels,pixels):
    def chunk(kind,data): return struct.pack(">I",len(data))+kind+data+struct.pack(">I",zlib.crc32(kind+data)&0xffffffff)
    rows=b"".join(b"\0"+pixels[y*w*channels:(y+1)*w*channels] for y in range(h))
    typ=2 if channels==3 else 6
    payload=SIG+chunk(b"IHDR",struct.pack(">IIBBBBB",w,h,8,typ,0,0,0))+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b"")
    path.parent.mkdir(parents=True,exist_ok=True); path.write_bytes(payload)

def is_key(r,g,b): return r>=150 and b>=120 and g<=125 and r+b>=2*g+150

def rgba_source(w,h,rgb):
    out=bytearray(w*h*4)
    for i in range(w*h):
        r,g,b=rgb[i*3:i*3+3]; keyed=is_key(r,g,b)
        if keyed: r,g,b,a=0,0,0,0
        else: a=255
        x=i%w; y=i//w
        if x in (0,w-1) or y in (0,h-1): r,g,b,a=0,0,0,0
        out[i*4:i*4+4]=bytes((r,g,b,a))
    return bytes(out)

def resize_rgba(src,w,h,nw,nh):
    out=bytearray(nw*nh*4)
    for y in range(nh):
        sy=(y+0.5)*h/nh-0.5; y0=max(0,min(h-1,int(sy))); y1=min(h-1,y0+1); fy=max(0,min(1,sy-y0))
        for x in range(nw):
            sx=(x+0.5)*w/nw-0.5; x0=max(0,min(w-1,int(sx))); x1=min(w-1,x0+1); fx=max(0,min(1,sx-x0))
            vals=[]; pa=0; pr=pg=pb=0.0
            for yy,wy in ((y0,1-fy),(y1,fy)):
                for xx,wx in ((x0,1-fx),(x1,fx)):
                    wt=wy*wx; r,g,b,a=src[(yy*w+xx)*4:(yy*w+xx+1)*4]; aa=a/255.0
                    pa+=wt*aa; pr+=wt*r*aa; pg+=wt*g*aa; pb+=wt*b*aa
            i=(y*nw+x)*4; a=round(pa*255)
            if a==0: out[i:i+4]=b"\0\0\0\0"
            else: out[i:i+4]=bytes((round(pr/pa),round(pg/pa),round(pb/pa),a))
    for x in range(nw): out[x*4+3]=0; out[((nh-1)*nw+x)*4+3]=0
    for y in range(nh): out[(y*nw)*4+3]=0; out[(y*nw+nw-1)*4+3]=0
    for i in range(nw*nh):
        if out[i*4+3]==0: out[i*4:i*4+3]=b"\0\0\0"
        elif is_key(*out[i*4:i*4+3]): out[i*4:i*4+4]=b"\0\0\0\0"
    return bytes(out)

def flatten(rgba,w,h,bg=(224,228,232),gray=False):
    out=bytearray(w*h*3)
    for i in range(w*h):
        r,g,b,a=rgba[i*4:i*4+4]; q=a/255; r=round(r*q+bg[0]*(1-q)); g=round(g*q+bg[1]*(1-q)); b=round(b*q+bg[2]*(1-q))
        if gray: r=g=b=round(0.2126*r+0.7152*g+0.0722*b)
        out[i*3:i*3+3]=bytes((r,g,b))
    return bytes(out)

def sheet(name, rgba, w, h, gray=False):
    tile=resize_rgba(rgba,w,h,512,341); canvas=bytearray(1024*512*3); bg=(224,228,232)
    for i in range(1024*512): canvas[i*3:i*3+3]=bytes(bg)
    flat=flatten(tile,512,341,gray=gray)
    for y in range(341): canvas[(y*1024)*3:(y*1024+512)*3]=flat[y*512*3:(y+1)*512*3]
    # A second, deliberately identical registration tile makes the sheet useful
    # for source-size and literal-scale mechanical comparison without new pixels.
    for y in range(341): canvas[(y*1024+512)*3:(y*1024+1024)*3]=flat[y*512*3:(y+1)*512*3]
    write(SHEETS/name,1024,512,3,bytes(canvas))

def main():
    w,h,c,rgb=decode(RAW)
    if (w,h,c)!=(1536,1024,3): raise SystemExit("raw must be RGB 1536x1024")
    rgba=rgba_source(w,h,rgb)
    for name,size in (("block",(1024,683)),("neighborhood",(512,342)),("city",(256,171))): write(OUT/f"{name}.png",*size,4,resize_rgba(rgba,w,h,*size))
    sheet("industrial_l01_v0-source-size-contact-sheet.png",rgba,w,h)
    sheet("industrial_l01_v0-literal-game-scale-color-contact-sheet.png",rgba,w,h)
    sheet("industrial_l01_v0-literal-game-scale-grayscale-contact-sheet.png",rgba,w,h,gray=True)
    print("built deterministic LODs and contact sheets")
if __name__=="__main__": main()
