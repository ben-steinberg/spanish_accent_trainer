#import gamified_training as engine
    
def PythonProcessor(audio_bytes):
    # This calls your research-backed formant extraction
    f1, f2 = engine.extract_formants(audio_bytes)
    return [float(f1), float(f2)]
