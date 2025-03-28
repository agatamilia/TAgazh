import os
import pytest
from app import app, db, UPLOAD_FOLDER
from models import Message
import io

@pytest.fixture
def client():
    app.config['TESTING'] = True
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
    with app.test_client() as client:
        with app.app_context():
            db.create_all()
        yield client
    # Cleanup
    for filename in os.listdir(UPLOAD_FOLDER):
        if filename.startswith("test_"):
            os.remove(os.path.join(UPLOAD_FOLDER, filename))

def test_audio_upload(client):
    # Prepare test audio file
    audio_data = io.BytesIO()
    # Create a minimal WAV file (0.5s silence)
    audio_data.write(b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x80>\x00\x00\x00}\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00')
    audio_data.seek(0)
    
    # Test valid upload
    response = client.post(
        '/api/transcribe',
        data={'audio': (audio_data, 'test_audio.wav')},
        content_type='multipart/form-data'
    )
    assert response.status_code == 200
    assert 'transcription' in response.json
    assert os.path.exists(os.path.join(UPLOAD_FOLDER, 'test_audio.wav'))

    # Test invalid file
    response = client.post(
        '/api/transcribe',
        data={'audio': (io.BytesIO(b'notaudio'), 'invalid.txt')},
        content_type='multipart/form-data'
    )
    assert response.status_code == 400

def test_audio_playback(client):
    # First upload a file
    test_file = os.path.join(UPLOAD_FOLDER, 'test_playback.wav')
    with open(test_file, 'wb') as f:
        f.write(b'RIFF$\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x80>\x00\x00\x00}\x00\x00\x02\x00\x10\x00data\x00\x00\x00\x00')
    
    # Test playback
    response = client.get('/uploads/audio/test_playback.wav')
    assert response.status_code == 200
    assert response.content_type == 'audio/wav'