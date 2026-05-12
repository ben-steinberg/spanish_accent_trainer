"""
server.py — Flask API server
Run from Accent Trainer root: python server.py
"""

from flask import Flask, request, jsonify
import numpy as np
import os, sys, traceback, ast


sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'engine'))

from gamified_training import get_features
from data_analysis import analyze_speaking, get_misses, find_suggested_words
from audio_recorder import transcribe_audio
from to_textgrid import to_textgrid
from phonemizer import phonemize
from phonemizer.backend.espeak.wrapper import EspeakWrapper
import speech_recognition as sr

app = Flask(__name__)

BASE_DIR    = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data")
ALIGNED_DIR = os.path.join(DATA_DIR, "aligned_text_grids")
FILES_DIR   = os.path.join(DATA_DIR, "files_for_alignment")
MFA_MODEL   = "spanish_mfa"
ESPEAK_PATH = '/opt/homebrew/Cellar/espeak-ng/1.52.0/lib/libespeak-ng.dylib'
DIALECT_EQUIVALENCES = {('θ', 's'), ('s', 'θ'), ('θ', 'z'), ('z', 'θ')}

if os.path.exists(ESPEAK_PATH):
    EspeakWrapper.set_library(ESPEAK_PATH)

# ══════════════════════════════════════════════════════════════
#  HEALTH CHECK
# ══════════════════════════════════════════════════════════════
@app.route('/ping', methods=['GET'])
def ping():
    return jsonify({"status": "ok"})

# ══════════════════════════════════════════════════════════════
#  PHONEMIZE  — Spanish word → IPA phoneme list
# ══════════════════════════════════════════════════════════════
@app.route('/phonemize', methods=['GET'])
def phonemize_word():
    try:
        word = request.args.get('word', '').strip().lower()
        if not word:
            return jsonify({"error": "No word provided"}), 400

        raw          = phonemize(word, language='es', backend='espeak', strip=True)
        phoneme_list = [p for p in raw if p.strip() and p not in ('ˈ', 'ˌ')]

        return jsonify({"phonemes": phoneme_list})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
        
@app.route('/phoneme_words', methods=['GET'])
def phoneme_words():
    try:
        should_be = request.args.get('should_be', '')
        actual = request.args.get('actual', '')
        data_path = os.path.join(BASE_DIR, "data")
        word_path = os.path.join(data_path, "word_counts.txt")
        
        should_be_words = []
        actual_words = []
        
        if os.path.exists(word_path):
            with open(word_path, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('words:'):
                        words = ast.literal_eval(line[6:])
                        for word, phonemes in words:
                            if should_be in phonemes and word not in should_be_words:
                                should_be_words.append(word)
                            if actual in phonemes and word not in actual_words:
                                actual_words.append(word)

        return jsonify({
            "should_be_words": should_be_words[:6],
            "actual_words":    actual_words[:6]
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
        
@app.route('/phoneme_history', methods=['GET'])
def phoneme_history():
    try:
        should_be = request.args.get('should_be', '')
        actual    = request.args.get('actual', '')
        miss_path = os.path.join(BASE_DIR, "data", "miss_tracker.txt")
        
        from datetime import datetime
        from collections import defaultdict
        
        daily_counts = defaultdict(int)
        current_date = None
        
        with open(miss_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line.endswith(':') and line.startswith('recording_'):
                    try:
                        date_str = '_'.join(line[:-1].split('_')[1:2])
                        current_date = date_str  # e.g. "2026-05-07"
                    except:
                        current_date = None
                elif current_date and (line.startswith('far misses:') or line.startswith('close misses:')):
                    prefix = 'far misses:' if line.startswith('far misses:') else 'close misses:'
                    misses = ast.literal_eval(line[len(prefix):])
                    for pair in misses:
                        if pair[0] == should_be and pair[1] == actual:
                            daily_counts[current_date] += 1
        
        return jsonify({"history": [{"date": d, "count": c}
                                     for d, c in sorted(daily_counts.items())]})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
        
@app.route('/progress', methods=['GET'])
def progress():

    miss_path = os.path.join(BASE_DIR, "data", "miss_tracker.txt")
    word_path = os.path.join(BASE_DIR, "data", "word_counts.txt")

    if not os.path.exists(miss_path):
        return jsonify({"trends": []})
    try:

        DIALECT_EQUIVALENCES = {('θ', 's'), ('s', 'θ'), ('θ', 'z'), ('z', 'θ')}

        # ── Read miss_tracker.txt ─────────────────────────────
        recordings = []
        current = None
        with open(miss_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line.endswith(':') and line.startswith('recording_'):
                    current = {'name': line[:-1], 'far': [], 'close': []}
                    recordings.append(current)
                elif current and line.startswith('far misses:'):
                    current['far'] = ast.literal_eval(line[11:])
                elif current and line.startswith('close misses:'):
                    current['close'] = ast.literal_eval(line[13:])

        if not recordings:
            return jsonify({"trends": []})

        # ── Read word_counts.txt ──────────────────────────────
        # Build dict: recording_name -> list of (word, phonemes)
        word_counts = {}
        current_name = None
        with open(word_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if line.endswith(':') and line.startswith('recording_'):
                    current_name = line[:-1]
                elif current_name and line.startswith('words:'):
                    word_counts[current_name] = ast.literal_eval(line[6:])

        # ── Count total phoneme appearances per recording ─────
        # For each recording, count how many times each phoneme appears
        # across all words said in that recording
        def count_phonemes(rec_name):
            counts = {}
            words = word_counts.get(rec_name, [])
            for word, phonemes in words:
                # phonemes is a string like "kaβaʎo"
                # we just count each character as a phoneme appearance
                for ch in phonemes:
                    if ch.strip():
                        counts[ch] = counts.get(ch, 0) + 1
            return counts

        # ── Split into recent vs older ────────────────────────
        split       = max(0, len(recordings) - 2)
        older_recs  = recordings[:split]
        recent_recs = recordings[split:]

        def compute_accuracy(recs):
            # Returns dict: phoneme_pair -> (misses, total_appearances)
            pair_misses = {}
            phoneme_totals = {}

            for rec in recs:
                name = rec['name']
                totals = count_phonemes(name)

                # Accumulate total appearances for each phoneme
                for ph, count in totals.items():
                    phoneme_totals[ph] = phoneme_totals.get(ph, 0) + count

                # Accumulate misses (far misses weighted more)
                for pair in rec['far']:
                    if tuple(pair) not in DIALECT_EQUIVALENCES:
                        key = f"{pair[0]}→{pair[1]}"
                        pair_misses[key] = pair_misses.get(key, 0) + 1

                for pair in rec['close']:
                    if tuple(pair) not in DIALECT_EQUIVALENCES:
                        key = f"{pair[0]}→{pair[1]}"
                        pair_misses[key] = pair_misses.get(key, 0) + 0.5

            # Compute accuracy per pair
            accuracies = {}
            for key, misses in pair_misses.items():
                should_be = key.split('→')[0] if '→' in key else key
                total = phoneme_totals.get(should_be, 0)
                if total > 0:
                    accuracies[key] = max(0.0, 1.0 - (misses / total))
                else:
                    accuracies[key] = 0.0
            return accuracies, pair_misses

        recent_acc, recent_misses = compute_accuracy(recent_recs)
        older_acc,  older_misses  = compute_accuracy(older_recs)

        # ── Build trends ──────────────────────────────────────
        trends = []
        all_keys = set(list(recent_acc.keys()) + list(older_acc.keys()))

        for key in all_keys:
            r_acc = recent_acc.get(key, None)
            o_acc = older_acc.get(key, None)
            r_miss = recent_misses.get(key, 0)
            o_miss = older_misses.get(key, 0)

            if r_acc is None and o_acc is not None:
                trend = "improving"  # was missing before, not now
            elif o_acc is None:
                trend = "same"       # only in recent, no baseline
            elif r_acc > o_acc + 0.05:
                trend = "improving"
            elif r_acc < o_acc - 0.05:
                trend = "worsening"
            else:
                trend = "same"

            r_pct = round((r_acc or 0) * 100)
            o_pct = round((o_acc or 0) * 100)

            trends.append({
                "phonemes":        key,
                "trend":           trend,
                "recent":          r_miss,
                "older":           o_miss,
                "recent_accuracy": r_pct,
                "older_accuracy":  o_pct,
            })

        trends.sort(key=lambda x: x["recent"], reverse=True)
        return jsonify({"trends": trends[:8]})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════
#  ANALYZE AUDIO  — real-time formant extraction
# ══════════════════════════════════════════════════════════════
@app.route('/analyze_audio', methods=['POST'])
def analyze_audio():
    try:
        audio_bytes = request.data
        if not audio_bytes:
            return jsonify({"error": "No audio data"}), 400

        frame       = np.frombuffer(audio_bytes, dtype=np.float32)
        frame_int16 = (frame * 32768).astype(np.int16)
        f1, f2, centroid, flatness, volume = get_features(frame_int16)

        return jsonify({
            "f1":       round(f1, 2),
            "f2":       round(f2, 2),
            "centroid": round(centroid, 2),
            "flatness": round(float(flatness), 4),
            "volume":   round(float(volume), 2)
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════
#  TRANSCRIBE  — speech-to-text only, no MFA (fast)
#  Returns what the user said so the app can show it immediately
# ══════════════════════════════════════════════════════════════
@app.route('/transcribe', methods=['POST'])
def transcribe_only():
    try:
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file"}), 400

        file      = request.files['audio']
        file_name = request.form.get('filename', 'recording')

        os.makedirs(FILES_DIR, exist_ok=True)
        save_path = os.path.join(FILES_DIR, f"{file_name}.wav")
        file.save(save_path)

        # Transcribe using Google Speech (same as audio_recorder.py)
        recognizer = sr.Recognizer()
        text = ""
        text = ""
        for attempt in range(3):
            try:
                with sr.AudioFile(save_path) as source:
                    audio_data = recognizer.record(source)
                text = recognizer.recognize_google(audio_data, language="es-ES")
                break
            except sr.UnknownValueError:
                text = "(couldn't understand audio)"
                break
            except Exception as e:
                if attempt == 2:
                    text = "(transcription error — try again)"
                else:
                    import time
                    time.sleep(1)

        # Also save the .txt so MFA can use it later
        txt_path = os.path.join(FILES_DIR, f"{file_name}.txt")
        with open(txt_path, 'w') as f:
            f.write(text)

        return jsonify({"transcription": text, "filename": file_name})

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════
#  UPLOAD RECORDING  — full MFA pipeline (slow, run after transcribe)
# ══════════════════════════════════════════════════════════════
import threading
import traceback

@app.route('/upload_recording', methods=['POST'])
def upload_recording():
    try:
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file"}), 400

        file = request.files['audio']
        file_name = request.form.get('filename', 'recording')

        os.makedirs(FILES_DIR, exist_ok=True)
        save_path = os.path.join(FILES_DIR, f"{file_name}.wav")
        file.save(save_path)

        txt_path = os.path.join(FILES_DIR, f"{file_name}.txt")
        if not os.path.exists(txt_path):
            transcribe_audio(file_name)

        # Run synchronously — wait for MFA to finish
        to_textgrid(FILES_DIR, MFA_MODEL, ALIGNED_DIR)
        close_misses, far_misses = analyze_speaking(ALIGNED_DIR, show_print=False)

        return jsonify({
            "close_misses": _counter_to_list(close_misses),
            "far_misses":   _counter_to_list(far_misses)
        })

    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════
#  MISSES  — cached miss_tracker.txt
# ══════════════════════════════════════════════════════════════
@app.route('/misses', methods=['GET'])
def misses():
    try:
        close, far = get_misses(os.path.join(BASE_DIR, "data"))
        return jsonify({
            "close_misses": _counter_to_list(close),
            "far_misses":   _counter_to_list(far)
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ══════════════════════════════════════════════════════════════
#  SUGGESTED WORDS
# ══════════════════════════════════════════════════════════════
@app.route('/suggested_words', methods=['GET'])
def suggested_words():
    try:
        n = int(request.args.get('n', 1))
        words, phonemes_list = find_suggested_words(os.path.join(BASE_DIR, "data"), n)
        return jsonify({
            "phonemes":        phonemes_list,
            "suggested_words": [{"word": w, "phonemes": p} for w, p in words]
        })
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# ─────────────────────────────────────────────────────────────
@app.route('/update_transcription', methods=['POST'])
def update_transcription():
    try:
        data = request.get_json()
        filename = data.get('filename', 'recording')
        text = data.get('text', '')
        txt_path = os.path.join(FILES_DIR, f"{filename}.txt")
        with open(txt_path, 'w') as f:
            f.write(text)
        return jsonify({"status": "ok"})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500
        
def _counter_to_list(counter):
    return [
        {"should_be": k[0], "actual": k[1], "count": v}
        for k, v in counter.most_common()
    ]
    
@app.route('/delete_recording', methods=['POST'])
def delete_recording():
    try:
        data = request.get_json()
        filename = data.get('filename', '')
        for ext in ['.wav', '.txt']:
            path = os.path.join(FILES_DIR, f"{filename}{ext}")
            if os.path.exists(path):
                os.remove(path)
        return jsonify({"status": "ok"})
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    os.makedirs(ALIGNED_DIR, exist_ok=True)
    os.makedirs(FILES_DIR, exist_ok=True)
    print("═" * 55)
    print("  Accent Trainer Server")
    print(f"  Base dir : {BASE_DIR}")
    print("  Running on http://0.0.0.0:5001")
    print("═" * 55)
    app.run(host='0.0.0.0', port=5001, debug=True)
