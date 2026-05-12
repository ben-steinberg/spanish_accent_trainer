import matplotlib
import matplotlib.pyplot as plt
import pyaudio
import numpy as np
import parselmouth
import librosa
from phonemizer import phonemize
from phonemizer.backend.espeak.wrapper import EspeakWrapper

ESPEAK_LIB_PATH = '/opt/homebrew/Cellar/espeak-ng/1.52.0/lib/libespeak-ng.dylib'
EspeakWrapper.set_library(ESPEAK_LIB_PATH)

SAMPLE_RATE = 44100
BUFFER_SIZE = 2048

VOWELS = {
    'a': (1450, 750), 'e': (1900, 450), 'i': (2300, 300),
    'o': (1000, 500), 'u': (800, 350), 'w': (900, 350),
    'j': (2200, 300), 'ʝ': (2100, 350)
}

CATEGORIES = {
    "FRICTION": ['s', 'f', 'x', 'θ'],
    "NASAL": ['m', 'n', 'ɲ', 'ŋ'],
    "POPS": ['p', 't', 'k', 'b', 'd', 'g'],
    "VIBRANT": ['r', 'ɾ'],
    "LIQUID": ['l'],
    "SOFT_B": ['β', 'ð', 'ɣ']
}

MAX_STABILITY = 5

def get_features(frame):
    try:
        norm = frame.astype(float) / 32768.0
        sound = parselmouth.Sound(norm, sampling_frequency=SAMPLE_RATE)
        f_obj = sound.to_formant_burg(max_number_of_formants=5)
        f1 = f_obj.get_value_at_time(1, sound.duration/2)
        f2 = f_obj.get_value_at_time(2, sound.duration/2)
        stft = np.abs(librosa.stft(norm, n_fft=BUFFER_SIZE))
        centroid = librosa.feature.spectral_centroid(S=stft, sr=SAMPLE_RATE)[0][0]
        flatness = librosa.feature.spectral_flatness(y=norm)[0][0]
        return (f1 or 0), (f2 or 0), centroid, flatness, np.mean(np.abs(frame))
    except:
        return 0, 0, 0, 0, 0

def train_speaking(input_word=None):
    matplotlib.use('TkAgg')
    plt.style.use('dark_background')
    fig = plt.figure(figsize=(14, 10))
    grid = plt.GridSpec(3, 2, height_ratios=[5, 2, 1])

    vowel_map = fig.add_subplot(grid[0, 0])
    vowel_map.set_xlim(2800, 600)
    vowel_map.set_ylim(1000, 200)
    vowel_map.set_title("Tongue and Mouth Position", fontsize=15)
    
    for v, (f2, f1) in VOWELS.items():
        vowel_map.add_artist(plt.Circle((f2, f1), 200, color='white', alpha=0.1))
        vowel_map.text(f2, f1, v, color='white', weight='bold', ha='center', va='center')
        pass
    
    live_dot, = vowel_map.plot([1500], [500], 'ro', ms=15, zorder=5)
    target_circle = plt.Circle((0, 0), 250, color='lime', fill=False, lw=2, alpha=0)
    
    vowel_map.add_artist(target_circle)
    hint_text = vowel_map.text(1700, 950, "", color='yellow', fontsize=14, ha='center', weight='bold')

    airflow_map = fig.add_subplot(grid[0, 1])
    airflow_map.set_title("Airflow Style", fontsize=15)
    airflow_map.set_xlim(0, 3)
    airflow_map.set_ylim(0, 1)
    airflow_map.set_xticks([0.5, 1.5, 2.5])
    airflow_map.set_xticklabels(["Smooth", "Hiss", "Impact"], color='white')
    airflow_map.set_yticks([])
    airflow_map.grid(False)

    vowel_bar = airflow_map.bar(0.5, 0, color='cyan', alpha=0.6, width=0.4)
    hiss_bar = airflow_map.bar(1.5, 0, color='magenta', alpha=0.6, width=0.4)
    impact_bar = airflow_map.bar(2.5, 0, color='lime', alpha=0.6, width=0.4)

    vowel_target = airflow_map.add_patch(plt.Rectangle((0.3, 0.35), 0.4, 0.5, color='lime', fill=False, lw=2, alpha=0))
    hiss_target = airflow_map.add_patch(plt.Rectangle((1.3, 0.35), 0.4, 0.5, color='lime', fill=False, lw=2, alpha=0))
    impact_target = airflow_map.add_patch(plt.Rectangle((2.3, 0.35), 0.4, 0.5, color='lime', fill=False, lw=2, alpha=0))

    progress = fig.add_subplot(grid[2, :])
    progress.set_axis_off()

    if not input_word:
        input_word = input("Enter Spanish word: ").lower().strip()
    
    raw_phonemes = phonemize(input_word, language='es', backend='espeak', strip=True)
    phoneme_list = [p for p in raw_phonemes if p.strip() and p != 'ˈ']
    
    display_letters = list(input_word)
    visuals = [progress.text(i + 1, 0.6, char.upper(), fontsize=45, ha='center', color='gray', alpha=0.3) for i, char in enumerate(display_letters)]
    
    phone_visuals = []
    p_offset = 0
    for i, char in enumerate(display_letters):
        if char == 'h' or char == ' ':
            continue
        if p_offset < len(phoneme_list):
            is_digraph_part = i > 0 and char == display_letters[i-1] and char in ['l', 'r']
            if not is_digraph_part:
                pv_text = progress.text(i + 1, 0.2, f"/{phoneme_list[p_offset]}/", fontsize=20, ha='center', color='cyan', alpha=0.1)
                phone_visuals.append({'text': pv_text, 'p_idx': p_offset, 'l_idx': i})
                p_offset += 1
        
    progress.set_xlim(0, len(display_letters) + 1)

    plt.tight_layout()
    plt.ion()
    plt.show()

    audio = pyaudio.PyAudio()
    stream = audio.open(format=pyaudio.paInt16, channels=1, rate=SAMPLE_RATE, input=True, frames_per_buffer=BUFFER_SIZE)

    letter_idx = 0
    phone_idx = 0
    stability = 0
    v_history = [0] * 5

    try:
        while phone_idx < len(phoneme_list) and plt.fignum_exists(fig.number):
            data = stream.read(BUFFER_SIZE, exception_on_overflow=False)
            frame = np.frombuffer(data, dtype=np.int16)
            f1, f2, cent, flat, volume = get_features(frame)
            v_history.append(volume)
            v_history.pop(0)

            vowel_target.set_alpha(0)
            hiss_target.set_alpha(0)
            impact_target.set_alpha(0)

            impact_count = 0
            trill_window = 0

            if volume > 100:
                current_char = display_letters[letter_idx] if letter_idx < len(display_letters) else ""

                if current_char == 'h' or current_char == ' ':
                    visuals[letter_idx].set_color('lime')
                    visuals[letter_idx].set_alpha(1.0)
                    letter_idx += 1
                    continue

                target_phone = phoneme_list[phone_idx]
                success = False
                msg = ""
                
                vol_delta = volume - np.mean(v_history)
                is_impact = (vol_delta > 180 and volume > 250) or (flat > 0.12)

                is_hiss = cent > 3200
                is_smooth = not is_impact and not is_hiss and volume > 120

                volume_height = min(0.95, volume / 700)
                hiss_height = min(0.95, cent / 5500)
                impact_height = min(0.95, vol_delta / 400)

                vowel_bar[0].set_height(volume_height if is_smooth else 0)
                hiss_bar[0].set_height(hiss_height if is_hiss else 0)
                impact_bar[0].set_height(impact_height if is_impact else 0)


                if target_phone in VOWELS:
                    vowel_target.set_alpha(0.8)
                    live_dot.set_data([f2], [f1])
                    t_f2, t_f1 = VOWELS[target_phone]
                    target_circle.set_center((t_f2, t_f1))
                    target_circle.set_alpha(0.5)
                    dist = np.sqrt((f2 - t_f2)**2 + (f1 - t_f1)**2)
                    
                    if f1 > t_f1 + 130:
                        msg = "CLOSE MOUTH"
                    elif f1 < t_f1 - 130:
                        msg = "OPEN WIDER"
                    elif f2 > t_f2 + 200:
                        msg = "PUSH TONGUE FORWARD"
                    elif f2 < t_f2 - 200:
                        msg = "PULL TONGUE BACK"
                    else:
                        msg = "PERFECT!"

                    if dist < 600 and 0.35 < volume_height:
                        success = True
                
                elif target_phone in CATEGORIES['VIBRANT']:
                    if target_phone == 'r':
                        impact_target.set_alpha(0.8)
                        msg = "RAPIDLY FLIP TONGUE UP AND DOWN"
                        
                        if is_impact:
                            impact_count += 1
                            trill_window = 0
                        else:
                            trill_window += 1
                        
                        if impact_count >= 2:
                            success = True
                            
                        elif trill_window > 10:
                            impact_count = 0

                    elif target_phone == 'ɾ':
                        impact_target.set_alpha(0.8)
                        msg = "SINGLE QUICK TAP"
                        if is_impact:
                            success = True

                elif target_phone in CATEGORIES['SOFT_B']:
                    vowel_target.set_alpha(0.8)
                    target_circle.set_alpha(0)
                    msg = "LIPS BARELY TOUCH (SOFT B/V)"
                    if is_smooth and 1200 < cent < 2600:
                        success = True

                elif target_phone in CATEGORIES['FRICTION'] or target_phone == 'x':
                    hiss_target.set_alpha(0.8)
                    target_circle.set_alpha(0)
                    msg = "GENERATE STEADY HISSING AIR"
                    if is_hiss and 0.35 < hiss_height:
                        success = True

                elif target_phone in CATEGORIES['POPS']:
                    impact_target.set_alpha(0.8)
                    target_circle.set_alpha(0)
                    msg = "SHARP POP OF AIR"
                    if is_impact and 0.35 < impact_height < 0.95:
                        success = True
                        stability = MAX_STABILITY
                
                else:
                    target_circle.set_alpha(0)
                    success = True

                hint_text.set_text(msg)

                if success:
                    stability += 1
                    if stability >= MAX_STABILITY:
                        curr_pv = next((p for p in phone_visuals if p['p_idx'] == phone_idx), None)
                        if curr_pv:
                            curr_pv['text'].set_color('lime')
                            curr_pv['text'].set_alpha(1.0)
                            l_idx = curr_pv['l_idx']
                            visuals[l_idx].set_color('lime')
                            visuals[l_idx].set_alpha(1.0)
                            
                            if l_idx + 1 < len(display_letters):
                                if display_letters[l_idx] == display_letters[l_idx+1] and display_letters[l_idx] in ['l', 'r']:
                                    visuals[l_idx+1].set_color('lime')
                                    visuals[l_idx+1].set_alpha(1.0)
                                    letter_idx += 1

                        phone_idx += 1
                        letter_idx += 1
                        stability = 0
                        target_circle.set_alpha(0)
                else:
                    stability = 0
            else:
                hint_text.set_text("SPEAK NOW...")

            fig.canvas.draw_idle()
            fig.canvas.flush_events()
            plt.pause(0.01)

        hint_text.set_text("EXCELLENT!")
        plt.pause(2)

    finally:
        stream.stop_stream()
        stream.close()
        audio.terminate()

if __name__ == "__main__":
    train_speaking()

'''
From here add phonemes below actual spelling
make it so much more intuitive

'''
