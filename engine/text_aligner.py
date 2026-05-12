import os
import pandas as pd
import numpy as np
import textgrid
from phonemizer import phonemize
from phonemizer.backend.espeak.wrapper import EspeakWrapper



base = os.path.dirname(os.path.abspath(__file__))

file = 'audio_test_1'

G2P_MODEL_NAME = "facebook/mms-g2p-es"


def get_phon_data(file_name):

    textgrid_path = os.path.join(base, "..", "data", "aligned_text_grids", f"{file_name}.TextGrid")
    
    if not os.path.exists(textgrid_path):
        print(f"Error: TextGrid file not found at {textgrid_path}")
        return None, None
        
    tg = textgrid.TextGrid.fromFile(textgrid_path)
    
        
    phoneme_tier = tg.getFirst(tierName = 'phones')
                 
    data_list = []

    for interval in phoneme_tier.intervals:
        phoneme_label = interval.mark
        start_time = interval.minTime
        end_time = interval.maxTime
        duration = end_time - start_time

        if phoneme_label.strip() == "":
            phoneme_label = "silence"

        data_list.append({
            'file': file_name,
            'phoneme': phoneme_label,
            'start_sec': start_time,
            'end_sec': end_time,
            'duration_sec': duration
        })

    df = pd.DataFrame(data_list)
    return df


def get_phonemes_by_word(file_name):
    """
    Returns a list of (word, [phonemes]) tuples using MFA's word tier boundaries.
    This is the key fix — by grouping phonemes per word, comparison drift
    resets at every word boundary instead of cascading across the whole sentence.
    """
    textgrid_path = os.path.join(base, "..", "data", "aligned_text_grids", f"{file_name}.TextGrid")

    if not os.path.exists(textgrid_path):
        print(f"Error: TextGrid file not found at {textgrid_path}")
        return []

    tg = textgrid.TextGrid.fromFile(textgrid_path)
    word_tier   = tg.getFirst(tierName='words')
    phoneme_tier = tg.getFirst(tierName='phones')

    result = []

    for word_interval in word_tier.intervals:
        word = word_interval.mark.strip()
        if not word:
            continue

        # Collect all phonemes whose time window falls inside this word's boundaries
        word_phonemes = []
        for ph_interval in phoneme_tier.intervals:
            ph_label = ph_interval.mark.strip()
            if not ph_label or ph_label.upper() in ('SIL', 'SP', 'SILENCE', ''):
                continue
            # Phoneme midpoint falls inside word boundary
            mid = (ph_interval.minTime + ph_interval.maxTime) / 2
            if word_interval.minTime <= mid <= word_interval.maxTime:
                word_phonemes.append(ph_label)

        if word_phonemes:
            result.append((word, word_phonemes))

    return result


def get_intended_words(file_name):
    textgrid_path = os.path.join(base, "..", "data", "aligned_text_grids", f"{file_name}.TextGrid")
    
    if not os.path.exists(textgrid_path):
        print(f"ts file doesn't exist lil bro: {textgrid_path}")
        return None, None
        
    tg = textgrid.TextGrid.fromFile(textgrid_path)
    
    word_tier = tg.getFirst(tierName = 'words')

    if word_tier is None:
        return ""
    
    words = []
    for interval in word_tier.intervals:
        if interval.mark.strip() != "":
            words.append(interval.mark)

    return " ".join(words)




if __name__ == '__main__':
    
    phoneme_df = get_phon_data(file)
    print(phoneme_df.head())
    intended_words = get_intended_words(file)

    if phoneme_df is not None:

        print("All Phonemes")
        print(phoneme_df.to_string(index=False, float_format='%.3f'))
        print()

        target_phonemes = ['p', 't̪', 'k', 'b', 'd̪', 'ɡ', 'β', 'ɣ', 'a', 'e', 'i', 'o', 'u', 'ð']
        
        plosive_analysis_df = phoneme_df[phoneme_df['phoneme'].isin(target_phonemes)].copy()

        print("Target Phonemes:")

        plosive_analysis_df = plosive_analysis_df.sort_values(by='start_sec')
        
        print(plosive_analysis_df.to_string(index=False, float_format='%.3f'))
        print()

        ESPEAK_LIB_PATH = '/opt/homebrew/Cellar/espeak-ng/1.52.0/lib/libespeak-ng.dylib'

        EspeakWrapper.set_library(ESPEAK_LIB_PATH)

        target = get_intended_words(file)

        phonemes = phonemize(target, language='es')
        phonemes = phonemes.replace(" ", "").strip()
        print("What should be said:   ", phonemes)

        said_array = phoneme_df[phoneme_df['phoneme'] != 'SILENCE']['phoneme'].tolist()
        actual_ipa_said = "".join(said_array)
        actual_ipa_said = actual_ipa_said.replace("silence", "").strip()

        print("What was actually said:", actual_ipa_said)
        
        stripped_actual = set(phonemes.replace(" ", "").strip())
        stripped_said = set(actual_ipa_said.replace(" ", "").strip())

        differences = stripped_actual.symmetric_difference(stripped_said)

        print("differences: ", differences)

        # Show word-by-word breakdown with new function
        print("\nWord-by-word phoneme breakdown:")
        by_word = get_phonemes_by_word(file)
        for word, phones in by_word:
            print(f"  {word}: {phones}")
