#!/usr/bin/env python3
"""
Setup script for the Whisper integration.
This script clones the Whisper repository from GitHub and installs its dependencies.
"""

import os
import subprocess
import sys
import logging

# Configure logging
logging.basicConfig(
  level=logging.INFO,
  format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def run_command(command, cwd=None):
  """Run a shell command and log the output"""
  logger.info(f"Running: {' '.join(command)}")
  try:
      process = subprocess.Popen(
          command,
          stdout=subprocess.PIPE,
          stderr=subprocess.PIPE,
          text=True,
          cwd=cwd
      )
      stdout, stderr = process.communicate()
      
      if stdout:
          logger.info(stdout)
      if stderr:
          logger.error(stderr)
          
      return process.returncode == 0
  except Exception as e:
      logger.error(f"Error running command: {e}")
      return False

def clone_whisper():
  """Clone the Whisper repository from GitHub"""
  current_dir = os.path.dirname(os.path.abspath(__file__))
  whisper_dir = os.path.join(current_dir, 'whisper')
  
  if os.path.exists(whisper_dir):
      logger.info(f"Whisper directory already exists at {whisper_dir}")
      # Pull latest changes
      logger.info("Pulling latest changes from GitHub...")
      return run_command(
          ["git", "pull", "origin", "main"],
          cwd=whisper_dir
      )
  
  logger.info("Cloning Whisper repository from GitHub...")
  return run_command(
      ["git", "clone", "https://github.com/openai/whisper.git"],
      cwd=current_dir
  )

def install_dependencies():
  """Install the required dependencies"""
  logger.info("Installing dependencies...")
  return run_command([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"])

def install_whisper():
  """Install Whisper in development mode"""
  current_dir = os.path.dirname(os.path.abspath(__file__))
  whisper_dir = os.path.join(current_dir, 'whisper')
  
  if not os.path.exists(whisper_dir):
      logger.error(f"Whisper directory not found at {whisper_dir}")
      return False
  
  logger.info("Installing Whisper in development mode...")
  return run_command(
      [sys.executable, "-m", "pip", "install", "-e", "."],
      cwd=whisper_dir
  )

def download_model():
  """Download the small model for better accuracy"""
  try:
      import whisper
      logger.info("Downloading the 'small' Whisper model...")
      whisper.load_model("small")
      logger.info("Model downloaded successfully")
      return True
  except Exception as e:
      logger.error(f"Error downloading model: {e}")
      return False

def main():
  """Main function"""
  logger.info("Setting up Whisper integration...")
  
  # Install dependencies
  if not install_dependencies():
      logger.error("Failed to install dependencies")
      return False
  
  # Clone Whisper repository
  if not clone_whisper():
      logger.error("Failed to clone Whisper repository")
      return False
  
  # Install Whisper
  if not install_whisper():
      logger.error("Failed to install Whisper")
      return False
  
  # Download model
  if not download_model():
      logger.error("Failed to download model")
      logger.warning("You may need to download the model manually")
  
  logger.info("Whisper setup completed successfully!")
  return True

if __name__ == "__main__":
  success = main()
  sys.exit(0 if success else 1)

