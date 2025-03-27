import os
import sys
import logging
import torch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def setup_whisper_path():
    """Add whisper to Python path"""
    whisper_dir = os.path.join(os.path.dirname(__file__), 'whisper')
    if os.path.exists(whisper_dir) and whisper_dir not in sys.path:
        sys.path.insert(0, whisper_dir)
        logger.info(f"Added {whisper_dir} to Python path")
        return True
    return False

def load_model(model_name="base"):
    try:
        print(f"Mencoba memuat model Whisper: {model_name}")
        import whisper
        model = whisper.load_model(model_name)
        print("Model Whisper berhasil dimuat")
        return model
    except Exception as e:
        print(f"Gagal memuat model: {str(e)}")
        return None

def transcribe(model, audio_path, language="id"):
    try:
        result = model.transcribe(
            audio_path,
            language=language,
            temperature=0.2
        )
        return result
    except Exception as e:
        return {"error": str(e)}