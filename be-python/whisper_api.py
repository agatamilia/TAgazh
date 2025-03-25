"""
Integration with OpenAI's Whisper model for speech recognition.
This module provides an interface to the Whisper model cloned from GitHub.
"""

import os
import sys
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def setup_whisper_path():
    """Add the whisper directory to the Python path"""
    # Assuming the whisper repository is cloned in the same directory as this file
    current_dir = os.path.dirname(os.path.abspath(__file__))
    whisper_dir = os.path.join(current_dir, 'whisper')
    
    if os.path.exists(whisper_dir):
        if whisper_dir not in sys.path:
            sys.path.append(whisper_dir)
            logger.info(f"Added {whisper_dir} to Python path")
        return True
    else:
        logger.error(f"Whisper directory not found at {whisper_dir}")
        return False

def load_model(model_name="small"):  # Changed from "base" to "small" for better accuracy
    """
    Load a Whisper model.
    
    Args:
        model_name (str): Name of the model to load (e.g., "base", "small", "medium")
        
    Returns:
        A Whisper model object or None if loading fails
    """
    try:
        # Add whisper to Python path
        if not setup_whisper_path():
            return None
        
        # Now we can import from the whisper package
        import whisper
        
        # Load the model
        logger.info(f"Loading Whisper model: {model_name}")
        model = whisper.load_model(model_name)
        logger.info(f"Whisper model {model_name} loaded successfully")
        
        return model
    except ImportError as e:
        logger.error(f"Failed to import Whisper: {e}")
        logger.error("Make sure you have cloned the Whisper repository from GitHub")
        return None
    except Exception as e:
        logger.error(f"Error loading Whisper model: {e}")
        return None

def transcribe(model, audio_path, language="id"):
    """
    Transcribe audio using the Whisper model.
    
    Args:
        model: The loaded Whisper model
        audio_path (str): Path to the audio file
        language (str): Language code (default: "id" for Indonesian)
        
    Returns:
        dict: Transcription result
    """
    try:
        # Transcribe with improved parameters
        result = model.transcribe(
            audio_path, 
            language=language,
            fp16=False,  # Disable fp16 for better compatibility
            verbose=True,  # Enable verbose output for debugging
            task="transcribe"  # Explicitly set task to transcribe
        )
        return result
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        return {"text": "", "error": str(e)}

