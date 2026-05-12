import pyaudio
import numpy as np
import matplotlib.pyplot as plt
import parselmouth
from gtts import gTTS
import io
import librosa


SAMPLE_RATE = 44100
BUFFER_SIZE = 1024  
MAX_LEN = 100      
PREV_WEIGHT = 0.7   


def generate_ghost(word, language='es'):
    print(f"generating ghost for: {word}...")
    tts = gTTS(text=word, lang=language)
    temp_io = io.BytesIO() # had to figure out what this was, found it online, keeps it in ram rather than actual storage
    tts.write_to_fp(temp_io)
    temp_io.seek(0)

    y, _ = librosa.load(temp_io, sr=SAMPLE_RATE)
    y, _ = librosa.effects.trim(y) # gets rid of silence
    sound = parselmouth.Sound(y, sampling_frequency=SAMPLE_RATE)
    formant_object = sound.to_formant_burg(time_step=0.01)

    times = np.arange(0, sound.duration, 0.01)
    f1_target = []
    f2_target = []

    for time in times:
        f1 = formant_object.get_value_at_time(1, time)
        f2 = formant_object.get_value_at_time(2, time)
        if not np.isnan(f1):
            f1_target.append(f1)
        else: 
            f1_target.append(0)

        if not np.isnan(f2):
            f2_target.append(f2)
        else: 
            f2_target.append(0)

    return np.array(f1_target), np.array(f2_target)

def get_live_formants(frame):
    try:
        normalized = frame.astype(float) / 32768.0
        sound = parselmouth.Sound(normalized, sampling_frequency=SAMPLE_RATE)
        f_obj = sound.to_formant_burg(maximum_formant=5000)
        
        # Check midpoint of the buffer
        f1 = f_obj.get_value_at_time(1, sound.duration/2)
        f2 = f_obj.get_value_at_time(2, sound.duration/2)
        
        amp = np.mean(np.abs(frame))
        return (f1 or 0), (f2 or 0), amp
    except:
        return 0, 0, 0

plt.style.use('dark_background')
fig, ax = plt.subplots(figsize=(12, 6))
x_axis = np.arange(MAX_LEN)

line_f1_target, = ax.plot(x_axis, np.zeros(MAX_LEN), color='cyan', alpha=0.15, lw=10, ls='--', label='Native F1 (Openness)')
line_f2_target, = ax.plot(x_axis, np.zeros(MAX_LEN), color='magenta', alpha=0.15, lw=10, ls='--', label='Native F2 (Tongue)')
line_f1, = ax.plot(x_axis, np.zeros(MAX_LEN), color='cyan', lw=2, label='Your F1')
line_f2, = ax.plot(x_axis, np.zeros(MAX_LEN), color='magenta', lw=2, label='Your F2')

ax.set_ylim(0, 3500)
ax.set_title("Fluency Trainer: Match the Shape & The Speed")
ax.legend(loc='upper right')
plt.ion()

audio_manager = pyaudio.PyAudio()
mic_stream = audio_manager.open(
    format=pyaudio.paInt16, 
    channels=1, 
    rate=SAMPLE_RATE, 
    input=True, 
    frames_per_buffer=BUFFER_SIZE
)

target_word = input("Enter a word to practice: ")
f1_ghost, f2_ghost = generate_ghost(target_word)

g_f1_full = np.zeros(MAX_LEN)
g_f2_full = np.zeros(MAX_LEN)
g_f1_full[:len(f1_ghost)] = f1_ghost # makes the duration fit to the word 
g_f2_full[:len(f2_ghost)] = f2_ghost
line_f1_target.set_ydata(g_f1_full)
line_f2_target.set_ydata(g_f2_full)

f1_history = np.zeros(MAX_LEN)
f2_history = np.zeros(MAX_LEN)
prev_f1 = 0
prev_f2 = 0
pointer = 0
is_speaking = False

try:
    while plt.fignum_exists(fig.number):
        raw_data = mic_stream.read(BUFFER_SIZE, exception_on_overflow=False)
        frame = np.frombuffer(raw_data, dtype=np.int16)
        
        f1, f2, amp = get_live_formants(frame)

        if amp > 120: 
            if not is_speaking:
                is_speaking = True
                pointer = 0
                f1_history.fill(0)
                f2_history.fill(0)
            
            if pointer < MAX_LEN:
                f1 = (PREV_WEIGHT * prev_f1) + ((1 - PREV_WEIGHT) * f1) # looked this part up, called
                f2 = (PREV_WEIGHT * prev_f2) + ((1 - PREV_WEIGHT) * f2) # Simple Exponential Smoothing
                
                f1_history[pointer] = f1
                f2_history[pointer] = f2
                prev_f1, prev_f2 = f1, f2
                pointer += 1
        else:
            is_speaking = False 

        line_f1.set_ydata(f1_history)
        line_f2.set_ydata(f2_history)
        
        fig.canvas.draw_idle()
        fig.canvas.flush_events()
        plt.pause(0.005) 

except KeyboardInterrupt:
    pass
finally:
    mic_stream.stop_stream()
    mic_stream.close()
    audio_manager.terminate()


