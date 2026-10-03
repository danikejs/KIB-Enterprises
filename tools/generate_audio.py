"""Áudio original do protótipo. Usa apenas a biblioteca padrão do Python."""
from pathlib import Path
from array import array
import math, random, wave
OUT=Path(__file__).resolve().parents[1]/'assets'/'audio'
OUT.mkdir(parents=True,exist_ok=True)
RATE=22050
rng=random.Random(17)
def save(name, data):
    peak=max(1,max(abs(v) for v in data))
    samples=array('h',(int(max(-1,min(1,v/peak))*26000) for v in data))
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setparams((1,2,RATE,0,'NONE','not compressed'))
        w.writeframes(samples.tobytes())
def effect(name, duration, freq, end, volume=.65):
    data=[]; phase=0.0
    for i in range(int(RATE*duration)):
        t=i/RATE; u=t/duration
        f=freq+(end-freq)*u
        phase+=math.tau*f/RATE
        env=min(1,t/.004)*math.exp(-6*u)*(1-u)
        data.append(volume*math.sin(phase)*env)
    save(name,data)
for args in [('hit',.10,660,360),('wall',.055,260,150),('perfect',.28,880,1320),('point',.35,440,660),('special',.4,240,1300),('click',.055,760,640)]: effect(*args)
beat=60/96
length=beat*64
music=[0.0]*int(RATE*length)
def tone(start,duration,freq,volume):
    begin=int(start*RATE)
    for k in range(int(duration*RATE)):
        index=begin+k
        if index>=len(music): break
        t=k/RATE; u=t/duration
        env=min(1,t/.01)*math.exp(-3*u)*(1-u)
        wave_value=math.sin(math.tau*freq*t)+.22*math.sin(math.tau*freq*2*t)
        music[index]+=volume*env*wave_value
roots=[45,45,41,41,48,48,43,43]
melody=[69,76,72,76,65,72,69,72,72,79,76,79,67,74,71,74]
for b in range(64):
    root=roots[(b//4)%len(roots)]
    tone(b*beat,.4,440*2**((root-69)/12),.22)
    if b%2==0:
        # Kick original com queda de frequência.
        for k in range(int(RATE*.16)):
            idx=int(b*beat*RATE)+k
            if idx<len(music):
                t=k/RATE
                music[idx]+=.09*math.sin(math.tau*(49*t+3*(1-math.exp(-25*t))))*math.exp(-26*t)
    for off in [0,.5]:
        for k in range(int(RATE*.025)):
            idx=int((b+off)*beat*RATE)+k
            if idx<len(music): music[idx]+=rng.uniform(-1,1)*.015*math.exp(-k/(RATE*.006))
    note=melody[(b//2)%len(melody)]
    if b%2==0:
        tone((b+.5)*beat,beat*.75,440*2**((note-69)/12),.1)
        tone((b+1.5)*beat,beat*.4,440*2**(((note+7)-69)/12),.055)
# Acordes de piano elétrico e caixa suave, com variação na segunda volta.
for b in range(64):
    root=roots[(b//4)%len(roots)]
    if b%4==0:
        for interval in [12,15,19,22]:
            tone(b*beat,beat*3.6,440*2**((root+interval-69)/12),.065)
    if b%2==1:
        for k in range(int(RATE*.10)):
            idx=int(b*beat*RATE)+k
            if idx<len(music):
                t=k/RATE
                music[idx]+=.045*rng.uniform(-1,1)*math.exp(-t*45)
    if b>=32 and b%4==3:
        tone((b+.5)*beat,beat*.4,440*2**((melody[(b//2)%16]+12-69)/12),.045)
save('arena_loop',music)
print('7 arquivos WAV gerados.')
