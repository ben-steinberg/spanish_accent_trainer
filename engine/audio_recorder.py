import os 
import speech_recognition as sr
import sounddevice as sd
from scipy.io.wavfile import write
import wavio as wv
from to_textgrid import to_textgrid


'''
This file should be for audio recording and to automatically make the textgrids that align with what you say. 
'''

# got this from here: https://www.geeksforgeeks.org/python/create-a-voice-recorder-using-python/

def record_audio(new = False): # new should like make a new file rather than override

    duration = ''

    while duration == '':
    
        duration = input("How many seconds would you like to record for?\n")
        try: 
            duration = int(duration)
            
            if duration < 1: 
                print("Please choose a larger value")
                duration = ''

        except: 
            print("Please choose a whole, non-negative number")
            duration = ''
    
    directory = os.path.join(os.getcwd(), "files_for_alignment")
    all_files = os.listdir(directory)
    
    input_amount = -1
    for file in all_files:
        if file.startswith('user_input_'):
            input_amount+= 1

    name = f"user_input_{input_amount}"

    recorded_filename = os.path.join("files_for_alignment", f"{name}.wav")

    freq = 22050

    recording = sd.rec(int(duration * freq), 
                    samplerate=freq, channels=1)

    print("Start Speaking in Spanish")

    sd.wait()

    wv.write(recorded_filename, recording, freq, sampwidth=2)


    r = sr.Recognizer()

    text = ''

    try:
        with sr.AudioFile(recorded_filename) as source:
            audio_data = r.record(source) 

        text = r.recognize_google(audio_data, language="es-ES")
        

    except sr.UnknownValueError:
        print("Couldn't understand what I said")
    except sr.RequestError as e:
        print(f"Couldn't request see {e}")



    print('text said: ', text)
    correction = ''
    actual_said = ''
    while not correction.startswith('y') and not correction.startswith('n'):
        correction = input("Was this transcription correct y/n\n")
        if correction.startswith('n'):
            actual_said = input('Type what you actually said: \n')

    if actual_said != '':
        text = actual_said

    with open(os.path.join("files_for_alignment", f"{name}.txt"), 'w') as file:
        file.write(text)

def transcribe_audio(name):

    try: 
        recorded_filename = os.path.join("files_for_alignment", f"{name}.wav")

    except Exception as e: 
        print(f"you probably typed it wrong but heres the error message {e}")


    r = sr.Recognizer()

    text = ''

    try:
        with sr.AudioFile(recorded_filename) as source:
            audio_data = r.record(source) 

        text = r.recognize_google(audio_data, language="es-ES")
        

    except sr.UnknownValueError:
        print("Couldn't understand what I said")
    except sr.RequestError as e:
        print(f"Couldn't request see: {e}")

    print('text said: ', text)

    with open(os.path.join("files_for_alignment", f"{name}.txt"), 'w') as file:
        file.write(text)

