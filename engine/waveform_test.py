import pyaudio
import numpy as np
import matplotlib.pyplot as plt

FRAMES = 1024 * 2             
FORMAT = pyaudio.paInt16     
CHANNELS = 1                 # puts it on mono
RATE = 44100                 # sample rate

p = pyaudio.PyAudio()

max_volume = 1000

stream = p.open(format=FORMAT, channels=CHANNELS, rate=RATE, 
                input=True, frames_per_buffer=FRAMES)


fig, ax = plt.subplots()
x = np.arange(0, 2 * FRAMES, 2)
line, = ax.plot(x, np.random.rand(FRAMES), '-', lw=2)

ax.set_title('Live Audio Waveform')
ax.set_ylim(-32768, 32767) # max range that im resetting later
ax.set_xlim(0, FRAMES)
plt.setp(ax, xticks=[0, FRAMES, FRAMES//2], yticks=[-32768, 0, 32767])

plt.show(block=False)

try:
    while True:
        data = stream.read(FRAMES, exception_on_overflow=False)
        data_int = np.frombuffer(data, dtype=np.int16)
        current_max = np.max(np.abs(data_int))

        if current_max > max_volume:
            max_volume = current_max + 50 
            ax.set_ylim(-max_volume, max_volume)

        line.set_ydata(data_int)
        line.set_ydata(data_int)
        fig.canvas.draw()
        fig.canvas.flush_events()
        
except KeyboardInterrupt:
    stream.stop_stream()
    stream.close()
    p.terminate()
