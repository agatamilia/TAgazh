from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
import os
import requests
import json
import tempfile
from dotenv import load_dotenv
import whisper
import logging
import sqlite3
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename
import subprocess
from flask_ngrok import run_with_ngrok

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)

# API Keys
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

# Database setup
DB_PATH = os.path.join(os.path.dirname(__file__), 'chatbot.db')
UPLOAD_FOLDER = 'uploads/audio'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
MAX_AUDIO_DURATION = 30  # seconds
MIN_AUDIO_DURATION = 0.5  # seconds

# Whisper model initialization
try:
    WHISPER_MODEL = whisper.load_model("base")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    WHISPER_MODEL = None

def init_db():
    """Initialize the SQLite database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS sessions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )
    ''')
    
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        content TEXT NOT NULL,
        role TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        image_path TEXT,
        FOREIGN KEY (session_id) REFERENCES sessions (id) ON DELETE CASCADE
    )
    ''')
    
    conn.commit()
    conn.close()

init_db()
@app.route('/info', methods=['POST'])
def handle_info():
    try:
        # Ambil data form biasa
        name = request.form.get('name')
        date = request.form.get('date')
        
        # Ambil file tunggal
        single_file = request.files.get('file')
        if single_file:
            single_filename = secure_filename(single_file.filename)
            single_file.save(os.path.join(UPLOAD_FOLDER, single_filename))
        
        # Ambil multiple files
        multiple_files = request.files.getlist('files[]')
        saved_files = []
        
        for file in multiple_files:
            if file.filename == '':
                continue
            filename = secure_filename(file.filename)
            file.save(os.path.join(UPLOAD_FOLDER, filename))
            saved_files.append(filename)
        
        return jsonify({
            'status': 'success',
            'name': name,
            'date': date,
            'single_file': single_file.filename if single_file else None,
            'multiple_files': saved_files
        })
        
    except Exception as e:
        logger.error(f"Error in /info endpoint: {str(e)}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files['audio']
    if audio_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    try:
        # Save file directly (no temp files)
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}.wav"
        filepath = os.path.join(UPLOAD_FOLDER, filename)
        audio_file.save(filepath)

        # Validate audio
        validation = validate_audio_file(filepath)
        if validation.get('error'):
            return jsonify(validation), 400

        # Transcribe
        result = WHISPER_MODEL.transcribe(
            filepath,
            language="id",
            task="transcribe"
        )
        transcription = result.get("text", "").strip()
        
        if not transcription:
            return jsonify({"error": "No speech detected"}), 400

        # Get AI response
        ai_response = get_deepseek_response(transcription)
        
        return jsonify({
            "status": "success",
            "transcription": transcription,
            "ai_response": ai_response,
            "audio_url": f"/uploads/audio/{filename}"
        })

    except Exception as e:
        logging.error(f"Transcription error: {str(e)}")
        return jsonify({"error": "Audio processing failed"}), 500

def validate_audio_file(filepath):
    """Validate audio file format and duration"""
    try:
        # Check duration
        duration = float(subprocess.check_output([
            'ffprobe', '-v', 'error',
            '-show_entries', 'format=duration',
            '-of', 'default=noprint_wrappers=1:nokey=1',
            filepath
        ]).decode('utf-8').strip())
        
        if duration < MIN_AUDIO_DURATION:
            return {"error": f"Audio too short (min {MIN_AUDIO_DURATION}s)"}
        if duration > MAX_AUDIO_DURATION:
            return {"error": f"Audio too long (max {MAX_AUDIO_DURATION}s)"}
            
        return {"valid": True, "duration": duration}
        
    except Exception as e:
        logging.error(f"Validation error: {str(e)}")
        return {"error": "Invalid audio file"}

@app.route('/')
def home():
    return jsonify({"status": "Flask is running!"})

@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM sessions ORDER BY updated_at DESC')
        sessions = [dict(row) for row in cursor.fetchall()]
        
        conn.close()
        return jsonify(sessions)
    except Exception as e:
        logger.error(f"Error getting sessions: {e}")
        return jsonify({"error": "Failed to get sessions"}), 500

@app.route('/api/sessions', methods=['POST'])
def create_session():
    try:
        data = request.json
        name = data.get('name', 'New Chat')
        
        session_id = str(uuid.uuid4())
        current_time = int(datetime.now().timestamp() * 1000)
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(
            'INSERT INTO sessions (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
            (session_id, name, current_time, current_time)
        )
        
        conn.commit()
        conn.close()
        
        return jsonify({
            "id": session_id,
            "name": name,
            "created_at": current_time,
            "updated_at": current_time
        })
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        return jsonify({"error": "Failed to create session"}), 500

@app.route('/api/sessions/<session_id>', methods=['PUT'])
def update_session(session_id):
    try:
        data = request.json
        name = data.get('name')
        
        if not name:
            return jsonify({"error": "Name is required"}), 400
        
        current_time = int(datetime.now().timestamp() * 1000)
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute(
            'UPDATE sessions SET name = ?, updated_at = ? WHERE id = ?',
            (name, current_time, session_id)
        )
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"error": "Session not found"}), 404
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "Session updated successfully"})
    except Exception as e:
        logger.error(f"Error updating session: {e}")
        return jsonify({"error": "Failed to update session"}), 500

@app.route('/api/sessions/<session_id>', methods=['DELETE'])
def delete_session(session_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Delete all messages in the session
        cursor.execute('DELETE FROM messages WHERE session_id = ?', (session_id,))
        
        # Delete the session
        cursor.execute('DELETE FROM sessions WHERE id = ?', (session_id,))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"error": "Session not found"}), 404
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "Session deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting session: {e}")
        return jsonify({"error": "Failed to delete session"}), 500

# Message management endpoints
@app.route('/api/sessions/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        
        cursor.execute('SELECT * FROM messages WHERE session_id = ? ORDER BY timestamp ASC', (session_id,))
        messages = [dict(row) for row in cursor.fetchall()]
        
        conn.close()
        return jsonify(messages)
    except Exception as e:
        logger.error(f"Error getting messages: {e}")
        return jsonify({"error": "Failed to get messages"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['POST'])
def save_message(session_id):
    try:
        data = request.json
        content = data.get('content')
        role = data.get('role')
        image_path = data.get('image_path')
        
        if not content or not role:
            return jsonify({"error": "Content and role are required"}), 400
        
        message_id = str(uuid.uuid4())
        current_time = int(datetime.now().timestamp() * 1000)
        
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Check if session exists
        cursor.execute('SELECT id FROM sessions WHERE id = ?', (session_id,))
        if not cursor.fetchone():
            conn.close()
            return jsonify({"error": "Session not found"}), 404
        
        # Save the message
        cursor.execute(
            'INSERT INTO messages (id, session_id, content, role, timestamp, image_path) VALUES (?, ?, ?, ?, ?, ?)',
            (message_id, session_id, content, role, current_time, image_path)
        )
        
        # Update session's updated_at timestamp
        cursor.execute(
            'UPDATE sessions SET updated_at = ? WHERE id = ?',
            (current_time, session_id)
        )
        
        conn.commit()
        conn.close()
        
        return jsonify({
            "id": message_id,
            "session_id": session_id,
            "content": content,
            "role": role,
            "timestamp": current_time,
            "image_path": image_path
        })
    except Exception as e:
        logger.error(f"Error saving message: {e}")
        return jsonify({"error": "Failed to save message"}), 500

@app.route('/api/sessions/<session_id>/messages/<message_id>', methods=['DELETE'])
def delete_message(session_id, message_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM messages WHERE id = ? AND session_id = ?', (message_id, session_id))
        
        if cursor.rowcount == 0:
            conn.close()
            return jsonify({"error": "Message not found"}), 404
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "Message deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting message: {e}")
        return jsonify({"error": "Failed to delete message"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['DELETE'])
def clear_messages(session_id):
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        cursor.execute('DELETE FROM messages WHERE session_id = ?', (session_id,))
        
        conn.commit()
        conn.close()
        
        return jsonify({"message": "All messages cleared successfully"})
    except Exception as e:
        logger.error(f"Error clearing messages: {e}")
        return jsonify({"error": "Failed to clear messages"}), 500

@app.route('/api/weather', methods=['GET'])
def get_weather():
    try:
        lat = request.args.get('lat', type=float)
        lon = request.args.get('lon', type=float)
        is_mock = request.args.get('mock', 'false').lower() == 'true'
        
        if is_mock:
            return jsonify(get_mock_weather_data())
            
        # Get weather data from OpenWeather
        weather_data = get_openweather_data(lat, lon)
        
        if not weather_data:
            return jsonify({
                'error': 'Failed to fetch weather data',
                'mock': True,
                'temperature': 30.0,
                'condition': 'sunny',
                'description': 'Cerah',
                'location': 'Jakarta',
                'advice': 'Cocok untuk panen atau pengeringan hasil panen'
            }), 500
        
        return jsonify({
            'temperature': weather_data['main']['temp'],
            'condition': map_weather_condition(weather_data['weather'][0]['main']),
            'description': weather_data['weather'][0]['description'],
            'location': weather_data.get('name', 'Unknown Location'),
            'advice': get_farming_advice(weather_data['weather'][0]['main'])
        })
        
    except Exception as e:
        logger.error(f"Weather API error: {e}")
        return jsonify({
            'error': str(e),
            'mock': True,
            'temperature': 30.0,
            'condition': 'sunny',
            'description': 'Cerah',
            'location': 'Jakarta',
            'advice': 'Cocok untuk panen atau pengeringan hasil panen'
        }), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        message = data.get('message', '')
        session_id = data.get('session_id', '')
        
        if not message:
            return jsonify({"error": "Message is required"}), 400
        
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "Anda adalah asisten pertanian PeTaniku. Tolong format jawaban dengan:\n"
                                            "1. Ganti **teks** dengan *teks* untuk bold\n"
                                            "2. Hindari penggunaan markdown seperti ### untuk heading\n"
                                            "3. Gunakan garis baru untuk pemisah bagian"},
                {"role": "user", "content": message}
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }
        
        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload
        )
        
        result = response.json()
        
        if response.status_code == 200:
            assistant_message = result['choices'][0]['message']['content']
            
            # Remove markdown headings and ensure proper bold formatting
            formatted_message = assistant_message.replace('###', '').replace('**', '*')
            
            # Create a clean version for TTS (without formatting markers)
            clean_tts_message = formatted_message.replace('*', '')
            
            if session_id:
                try:
                    conn = sqlite3.connect(DB_PATH)
                    cursor = conn.cursor()
                    
                    # Save user message
                    user_message_id = str(uuid.uuid4())
                    current_time = int(datetime.now().timestamp() * 1000)
                    
                    cursor.execute(
                        'INSERT INTO messages (id, session_id, content, role, timestamp) VALUES (?, ?, ?, ?, ?)',
                        (user_message_id, session_id, message, 'user', current_time)
                    )
                    
                    # Save assistant message
                    assistant_message_id = str(uuid.uuid4())
                    current_time = int(datetime.now().timestamp() * 1000)
                    
                    cursor.execute(
                        'INSERT INTO messages (id, session_id, content, role, timestamp) VALUES (?, ?, ?, ?, ?)',
                        (assistant_message_id, session_id, formatted_message, 'assistant', current_time)
                    )
                    
                    cursor.execute(
                        'UPDATE sessions SET updated_at = ? WHERE id = ?',
                        (current_time, session_id)
                    )
                    
                    conn.commit()
                    conn.close()
                except Exception as e:
                    logger.error(f"Error saving messages to database: {e}")
            
            return jsonify({
                "response": formatted_message,
                "clean_tts_message": clean_tts_message,
                "is_farming_related": True
            })
        else:
            logger.error(f"DeepSeek API error: {result}")
            return jsonify({"error": "Failed to get response from AI", "details": result}), response.status_code
            
    except Exception as e:
        logger.error(f"Chat API error: {e}")
        return jsonify({"error": "An error occurred while processing your message"}), 500

# @app.route('/api/debug/audio', methods=['POST'])
# def debug_audio():
#     audio_file = request.files['audio']
#     temp_path = "/tmp/debug_audio.wav"
#     audio_file.save(temp_path)
    
#     return jsonify({
#         "file_size": os.path.getsize(temp_path),
#         "first_bytes": str(open(temp_path, 'rb').read(100))  # 100 byte pertama
#     })

# @app.route('/api/upload', methods=['POST'])
# def upload_file():
#     if 'file' not in request.files:
#         return jsonify({"error": "No file provided"}), 400

#     uploaded_file = request.files['file']
#     if uploaded_file.filename == '':
#         return jsonify({"error": "No file selected"}), 400

#     try:
#         # Generate unique filename
#         file_ext = os.path.splitext(uploaded_file.filename)[1].lower()
#         unique_filename = f"{uuid.uuid4()}{file_ext}"
#         file_path = os.path.join(UPLOAD_FOLDER, unique_filename)
#         uploaded_file.save(file_path)

#         # Generate appropriate response based on file type
#         if file_ext in ['.jpg', '.jpeg', '.png', '.gif']:
#             response = "Gambar berhasil diunggah. Silakan jelaskan pertanyaan Anda tentang gambar ini."
#         elif file_ext in ['.pdf', '.doc', '.docx', '.txt']:
#             response = "Dokumen berhasil diunggah. Silakan ajukan pertanyaan tentang dokumen ini."
#         else:
#             response = "File berhasil diunggah. Silakan ajukan pertanyaan terkait file ini."

#         return jsonify({
#             "message": "File uploaded successfully",
#             "file_path": unique_filename,
#             "response": response
#         })

#     except Exception as e:
#         logger.error(f"File upload error: {str(e)}")
#         return jsonify({"error": "File upload failed"}), 500

@app.route('/uploads/audio/<filename>')
def serve_audio(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

def load_whisper_model():
    try:
        # Gunakan model 'base' untuk keseimbangan antara kecepatan dan akurasi
        # Untuk produksi, pertimbangkan 'small' atau 'medium'
        model = whisper.load_model("base")
        
        # Validasi model
        test_result = model.transcribe("test_audio.wav", language="id", verbose=False)
        if not test_result.get("text"):
            raise RuntimeError("Model test failed")
            
        return model
    except Exception as e:
        logger.error(f"Failed to load Whisper model: {str(e)}")
        return None
# Dalam fungsi pembuatan app
app.whisper_model = load_whisper_model()
def map_weather_condition(weather_main):
    """Map OpenWeather conditions to our frontend conditions"""
    weather_main = weather_main.lower()
    
    if any(x in weather_main for x in ['clear', 'sun']):
        return 'sunny'
    elif any(x in weather_main for x in ['cloud', 'fog', 'mist', 'haze']):
        return 'cloudy'
    elif any(x in weather_main for x in ['rain', 'drizzle', 'shower', 'thunder', 'storm']):
        return 'rainy'
    else:
        return 'cloudy'  # Default
def get_openweather_data(lat, lon):
    """Fetch weather data from OpenWeather API"""
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OPENWEATHER_API_KEY}&units=metric&lang=id"
        response = requests.get(url)
        response.raise_for_status()  # Raises an HTTPError for bad responses
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"OpenWeather API error: {e}")
        return None
def get_farming_advice(weather_main):
    """Get farming advice based on weather condition"""
    weather_main = weather_main.lower()
    
    if any(x in weather_main for x in ['clear', 'sun']):
        return "Cocok untuk panen atau pengeringan hasil panen"
    elif any(x in weather_main for x in ['cloud', 'fog', 'mist', 'haze']):
        return "Baik untuk menanam bibit atau penyemprotan pestisida"
    elif any(x in weather_main for x in ['rain', 'drizzle', 'shower']):
        return "Hindari pemupukan dan penyemprotan pestisida"
    elif any(x in weather_main for x in ['thunder', 'storm']):
        return "Pastikan drainase lahan baik untuk mencegah genangan"
    else:
        return "Pantau kondisi tanaman secara berkala"
def get_mock_weather_data():
    """Return mock weather data for testing"""
    return {
        'temperature': 30.0,
        'condition': 'sunny',
        'description': 'Cerah',
        'location': 'Jakarta',
        'advice': 'Cocok untuk panen atau pengeringan hasil panen'
    }
if __name__ == '__main__':
    app.run()
    # app.run(host='0.0.0.0', port=8080, debug=True)
    
