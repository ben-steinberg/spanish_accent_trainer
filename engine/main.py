import os 
from to_textgrid import to_textgrid
from audio_recorder import record_audio, transcribe_audio
from data_analysis import analyze_speaking, get_misses, find_suggested_words
from gamified_training import train_speaking

directory = os.path.join(os.getcwd(), "aligned_text_grids")

record_audio_q = ''

while not record_audio_q.startswith('y') and not record_audio_q.startswith('n'):
    record_audio_q = input("\nWould you like to record audio y/n?\n")
    if record_audio_q.startswith('y'):
        record_audio()
        print("Recorded! Off to create a TextGrid...")
        to_textgrid("files_for_alignment", "spanish_mfa", "aligned_text_grids")

transcribe_audio_q = ''

# for now this part is fine but you gotta like drag and drop in files_for_alignment

while not transcribe_audio_q.startswith('y') and not transcribe_audio_q.startswith('n'):
    transcribe_audio_q = input("\nWould you like to transcribe an audio so I can analyze it y/n?\n")
    if transcribe_audio_q.startswith('y'):
        transcribe_file_name = input("What is the name of the file? (don't include .wav)\n")
        transcribe_audio(transcribe_file_name)
        print("Transcribed! Off to create a TextGrid...")
        to_textgrid("files_for_alignment", "spanish_mfa", "aligned_text_grids")

use_textgrid_q = ''
while not use_textgrid_q.startswith('y') and not use_textgrid_q.startswith('n'):
    use_textgrid_q = input("\nWould you just like to run the Textgrid Conversion y/n?\n")
    if use_textgrid_q.startswith('y'):
        print("Off to create a TextGrid...")
        to_textgrid("files_for_alignment", "spanish_mfa", "aligned_text_grids")

close_misses, far_misses = [], []
analyze_speaking_q = ''
while not analyze_speaking_q.startswith('y') and not analyze_speaking_q.startswith('n'):
    analyze_speaking_q = input("\nWould you like to analyze the files? y/n?\n")
    if analyze_speaking_q.startswith('y'):
        print("Analyzing Files")
        close_misses, far_misses = analyze_speaking(directory, show_print = False, show_phonemes = False)
    else: 
        close_misses, far_misses = get_misses(os.getcwd())

print("Close Misses: ", close_misses)
print("Far Misses: ", far_misses)      

suggested_words, phoneme_list = find_suggested_words(os.getcwd(), 1)
print(f"\nThese are the phonemes you struggle with most, the first {int(len(phoneme_list) / 2)} being ones that you miss by a lot, and the rest being close misses ", phoneme_list)
print("Suggested Words to Practice: ", suggested_words)


practice_q = ''
while not practice_q.startswith('y') and not practice_q.startswith('n'):
    practice_q = input("\nWould you like to practice using some of these words? y/n?\n")
    if practice_q.startswith('y'):
        train_speaking()
        practice_q = ''


'''
from here, i have to make it some sort of loop, where it looks only at the last couple of 
files, and sees if you improved on the misses, and then finds new ones to work on.


'''