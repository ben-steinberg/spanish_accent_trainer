import os
from text_aligner import get_phon_data, get_intended_words, get_phonemes_by_word
from phonemizer.backend.espeak.wrapper import EspeakWrapper
from phonemizer import phonemize
from collections import Counter
import panphon
import panphon.distance
import ast
import pandas as pd
from datetime import datetime
import math



DIALECT_EQUIVALENCES = {
    ('θ', 's'), ('s', 'θ'),
    ('θ', 'z'), ('z', 'θ'),
}

def get_phonetic_difference(p1, p2):
    distance = panphon.distance.Distance()
    phoneme_dist = distance.feature_edit_distance(p1, p2)
    return phoneme_dist

def merge_diacritics(phones):
    """
    Combine the dental diacritic '̪' with its preceding character so
    't̪' is one element ['t̪'], not two ['t', '̪'].
    Call this on both sides before comparing so the diacritic is never
    seen as a standalone phoneme.
    """
    result = []
    for ch in phones:
        if ch == '\u032a' and result:
            result[-1] = result[-1] + ch  # merge into previous character
        else:
            result.append(ch)
    return result

def is_dentalized_equivalent(p1, p2):
    """
    Return True if the only difference between two phonemes is the
    dental diacritic — e.g. 't' vs 't̪', 'd' vs 'd̪'.
    These are not pronunciation errors, just transcription variants.
    """
    return p1.replace('\u032a', '') == p2.replace('\u032a', '')

def get_aligned_differences(should_be, actual, show_print=True):
    """
    Compare two flat phoneme lists.
    Used per-word (called from get_aligned_differences_by_word),
    so drift can never cascade across word boundaries.
    """
    # Merge diacritics on both sides first so '̪' is never a standalone element
    should_be = merge_diacritics(should_be)
    actual    = merge_diacritics(actual)

    i = 0
    j = 0
    close_misses = []
    large_misses = []

    while i < len(should_be) and j < len(actual):
        # Treat dentalized variants as equivalent — not a miss at all
        if should_be[i] == actual[j] \
           or is_dentalized_equivalent(should_be[i], actual[j]) \
           or get_phonetic_difference(should_be[i], actual[j]) < 0.0417:
            if should_be[i] != actual[j] and should_be[i] and actual[j]:
                if not is_dentalized_equivalent(should_be[i], actual[j]) \
                   and (should_be[i], actual[j]) not in DIALECT_EQUIVALENCES:
                    close_misses.append((should_be[i], actual[j]))
                if show_print:
                    print(f"  similar: /{should_be[i]}/ → /{actual[j]}/")
            i += 1
            j += 1
            continue

        if j + 1 < len(actual) and get_phonetic_difference(should_be[i], actual[j+1]) < 0.0417:
            if show_print:
                print(f"  extra in actual: /{actual[j]}/")
            j += 1
        elif i + 1 < len(should_be) and get_phonetic_difference(should_be[i+1], actual[j]) < 0.0417:
            if show_print:
                print(f"  extra in should_be: /{should_be[i]}/")
            i += 1
        else:
            if show_print:
                print(f"  MISS: should=/{should_be[i]}/ got=/{actual[j]}/")
            if (should_be[i], actual[j]) not in DIALECT_EQUIVALENCES:
                large_misses.append((should_be[i], actual[j]))
            i += 1
            j += 1

    return close_misses, large_misses


def get_aligned_differences_by_word(file_name, show_print=True):
    """
    THE KEY FIX: compare phonemes word-by-word using MFA's word tier.

    Instead of joining everything into one long string (where a single
    insertion/deletion throws off every subsequent comparison), we compare
    each word independently. Drift resets at every word boundary.
    """
    ESPEAK_LIB_PATH = '/opt/homebrew/Cellar/espeak-ng/1.52.0/lib/libespeak-ng.dylib'
    EspeakWrapper.set_library(ESPEAK_LIB_PATH)

    # MFA's actual phoneme output, grouped by word
    mfa_by_word = get_phonemes_by_word(file_name)

    all_close = []
    all_far   = []

    SKIP_WORDS = {'uh', 'um', 'ah', 'eh', 'mm', 'hmm', 'sp', 'sil', '<unk>'}

    for word, actual_phones in mfa_by_word:
        if word.lower() in SKIP_WORDS or len(word) <= 1:
            if show_print:
                print(f"\nSkipping filler: '{word}'")
            continue

        # phonemize returns a plain IPA string — split into chars and let
        # merge_diacritics inside get_aligned_differences handle the dental diacritic
        expected_ipa    = phonemize(word.lower(), language='es').strip()
        expected_phones = list(expected_ipa.replace(' ', ''))
        actual_clean    = list(actual_phones)

        if show_print:
            print(f"\nWord: '{word}'")
            print(f"  expected: {expected_phones}")
            print(f"  actual:   {actual_clean}")

        close, far = get_aligned_differences(expected_phones, actual_clean, show_print=show_print)
        all_close.extend(close)
        all_far.extend(far)

    return all_close, all_far


def get_words_and_phonemes(file_name):
    word_array = []
    path = os.path.dirname(os.path.abspath(__file__))
    directory = os.path.join(path, "..", "data", "files_for_alignment", file_name + ".txt")
    with open(directory, 'r') as f:
        text = f.read()
        words = text.split()
        for word in words:
            word_array.append((word.strip().lower(), phonemize(word.strip().lower(), language='es').replace(" ", "").strip()))

    return word_array


def analyze_speaking(directory, show_print=True, show_phonemes=False):
    data_dir      = os.path.join(directory, "..")
    file_path     = os.path.join(data_dir, "miss_tracker.txt")
    word_file_path = os.path.join(data_dir, "word_counts.txt")
    all_files     = os.listdir(directory)
    all_textgrid  = []

    for file in all_files:
        if file.endswith('.TextGrid'):
            prepped_file = file[:-9]
            all_textgrid.append(prepped_file)

    print(all_textgrid)

    for file in all_textgrid:
        phoneme_df = get_phon_data(file)

        if isinstance(phoneme_df, tuple):
            phoneme_df = phoneme_df[0]

        if phoneme_df is not None and isinstance(phoneme_df, pd.DataFrame):
            if show_phonemes:
                print("All Phonemes")
                print(phoneme_df.to_string(index=False, float_format='%.3f'))
                print()

            ESPEAK_LIB_PATH = '/opt/homebrew/Cellar/espeak-ng/1.52.0/lib/libespeak-ng.dylib'
            EspeakWrapper.set_library(ESPEAK_LIB_PATH)

            target = get_intended_words(file)

            if show_print:
                print(f"\nFile: {file}")
                print(f"Text: {target}")

            already_written = False
            if os.path.exists(file_path):
                with open(file_path) as reader:
                    for line in reader:
                        if line.strip() == f'{file}:':
                            already_written = True

            print(f"already written: {already_written} for file: {file}")

            if not already_written:
                # ── FIXED: word-by-word comparison instead of flat string ──
                close_misses, far_misses = get_aligned_differences_by_word(
                    file, show_print=show_print
                )

                if os.path.exists(file_path):
                    with open(file_path, 'a') as writer:
                        writer.write(f"\n{file}:")
                        writer.write(f"\nclose misses:{close_misses}")
                        writer.write(f"\nfar misses:{far_misses}")
                else:
                    with open(file_path, 'w') as writer:
                        writer.write(f"\n{file}:")
                        writer.write(f"\nclose misses:{close_misses}")
                        writer.write(f"\nfar misses:{far_misses}")

            already_written = False
            if os.path.exists(word_file_path):
                with open(word_file_path) as reader:
                    for line in reader:
                        if line.strip() == f'{file}:':
                            already_written = True

            if not already_written:
                words = get_words_and_phonemes(file)
                with open(word_file_path, 'a') as writer:
                    writer.write(f"\n{file}:")
                    writer.write(f"\nwords:{words}")

    all_close = []
    all_far   = []
    print("TextGrids found:", all_textgrid)
    print("Looking in:", directory)
    if not os.path.exists(file_path):
        return Counter(), Counter()

    with open(file_path) as reader:
        text = reader.readlines()
        for line in text:
            line = line.strip()
            if line.startswith('close misses:'):
                all_close.append(ast.literal_eval(line[13:]))
            if line.startswith('far misses:'):
                all_far.append(ast.literal_eval(line[11:]))

    to_close_counter = [s for arr in all_close for s in arr]
    to_far_counter   = [s for arr in all_far   for s in arr]

    close_counter = Counter(to_close_counter)
    far_counter   = Counter(to_far_counter)

    if show_print:
        print("Close Counter:", close_counter)
        print("Far Counter:  ", far_counter)

    return close_counter, far_counter

def get_misses(path):
    all_close_list = []
    all_far_list = []
    miss_path = os.path.join(path, "miss_tracker.txt")
    try:
        with open(miss_path, 'r', encoding='utf-8') as reader:
            for line in reader:
                line = line.strip()
                if line.startswith('close misses:'):
                    misses = ast.literal_eval(line[13:])
                    all_close_list.extend(misses)
                elif line.startswith('far misses:'):
                    misses = ast.literal_eval(line[11:])
                    all_far_list.extend(misses)
    except FileNotFoundError:
        print(f"Error: {path} not found.")
        return Counter(), Counter()
    except Exception as e:
        print(f"An error occurred: {e}")
        return Counter(), Counter()

    close_counter = Counter(all_close_list)
    far_counter = Counter(all_far_list)
    return close_counter, far_counter

    
DECAY_RATE = 0.1

def get_weighted_misses(path):
    miss_path = os.path.join(path, "miss_tracker.txt")
    now = datetime.now()
    
    weighted_close = {}
    weighted_far = {}
    
    try:
        with open(miss_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        current_date = None
        for line in lines:
            line = line.strip()
            if line.endswith(':') and line.startswith('recording_'):
                try:
                    date_str = '_'.join(line[:-1].split('_')[1:3])
                    current_date = datetime.strptime(date_str, '%Y-%m-%d_%H-%M-%S')
                except:
                    current_date = now
                    
            elif line.startswith('close misses:') and current_date:
                days_ago = (now - current_date).total_seconds() / 86400
                weight = math.exp(-DECAY_RATE * days_ago)
                misses = ast.literal_eval(line[13:])
                for pair in misses:
                    if pair not in DIALECT_EQUIVALENCES:
                        weighted_close[pair] = weighted_close.get(pair, 0) + weight
                        
            elif line.startswith('far misses:') and current_date:
                days_ago = (now - current_date).total_seconds() / 86400
                weight = math.exp(-DECAY_RATE * days_ago)
                misses = ast.literal_eval(line[11:])
                for pair in misses:
                    if pair not in DIALECT_EQUIVALENCES:
                        weighted_far[pair] = weighted_far.get(pair, 0) + weight
                        
    except FileNotFoundError:
        return {}, {}
    
    return weighted_close, weighted_far

def find_suggested_words(path, number_of_phonemes=1):
    close_counter, far_counter = get_misses(path)
    print(far_counter)

    phoneme_list = []
    close_target_list = close_counter.most_common(number_of_phonemes)
    far_target_list   = far_counter.most_common(number_of_phonemes)

    for target in far_target_list:
        phoneme_list.append(target[0][0])
    for target in close_target_list:
        phoneme_list.append(target[0][0])

    print("most frequently missed:", phoneme_list)
    suggested_words = []

    for target_char in phoneme_list:
        suggested_words_for_char = []
        word_path = os.path.join(path, "word_counts.txt")
        with open(word_path, 'r', encoding='utf-8') as reader:
            for line in reader:
                line = line.strip()
                if line.startswith('words:'):
                    words = ast.literal_eval(line[6:])
                    for word, phonemes in words:
                        if target_char in phonemes and (word, phonemes) not in suggested_words_for_char:
                            suggested_words_for_char.append((word, phonemes))
        suggested_words.extend(list(suggested_words_for_char))

    return suggested_words, phoneme_list
