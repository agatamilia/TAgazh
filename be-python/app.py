from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import requests
import json
import tempfile
from dotenv import load_dotenv
import whisper_api
import logging
import sqlite3
import uuid
from datetime import datetime
from waitress import serve
import requests
from flask_ngrok import run_with_ngrok
# from flask_cors import CORS

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)
# CORS(app)  # Enable CORS for all routes

# API Keys
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

# Database setup
DB_PATH = os.path.join(os.path.dirname(__file__), 'chatbot.db')

def init_db():
  """Initialize the SQLite database"""
  conn = sqlite3.connect(DB_PATH)
  cursor = conn.cursor()
  
  # Create sessions table
  cursor.execute('''
  CREATE TABLE IF NOT EXISTS sessions (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
  )
  ''')
  
  # Create messages table
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
  logger.info(f"Database initialized at {DB_PATH}")

# Initialize database on startup
init_db()

# Load Whisper model
whisper_model = None
try:
    whisper_model = whisper_api.load_model("base")
    if whisper_model:
        logger.info("Whisper model loaded successfully")
    else:
        logger.error("Failed to load Whisper model")
except Exception as e:
    logger.error(f"Error initializing Whisper: {e}")

@app.route('/')
def home():
    return jsonify({"status": "Flask is running!"})

@app.route('/api/health')
def health_check():
    return jsonify({"status": "healthy"}), 200
# Session management endpoints
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
        
        # Call DeepSeek API without keyword filtering
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "Anda adalah asisten pertanian yang membantu petani Indonesia. Berikan saran praktis tentang teknik bertani, cuaca, pengendalian hama, dan pengelolaan tanaman. Jawaban harus praktis, informatif, dan mudah dipahami dalam Bahasa Indonesia. Berikan jawaban yang lengkap dan detail."},
                {"role": "user", "content": message}
            ],
            "temperature": 0.7,
            "max_tokens": 1000  # Increased from 500 to 1000 for more detailed responses
        }
        
        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload
        )
        
        result = response.json()
        
        if response.status_code == 200:
            assistant_message = result['choices'][0]['message']['content']
            
            # If session_id is provided, save the messages to the database
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
                        (assistant_message_id, session_id, assistant_message, 'assistant', current_time)
                    )
                    
                    # Update session's updated_at timestamp
                    cursor.execute(
                        'UPDATE sessions SET updated_at = ? WHERE id = ?',
                        (current_time, session_id)
                    )
                    
                    conn.commit()
                    conn.close()
                except Exception as e:
                    logger.error(f"Error saving messages to database: {e}")
            
            return jsonify({
                "response": assistant_message,
                "is_farming_related": True  # Always return true to avoid restrictions
            })
        else:
            logger.error(f"DeepSeek API error: {result}")
            return jsonify({"error": "Failed to get response from AI", "details": result}), response.status_code
            
    except Exception as e:
        logger.error(f"Chat API error: {e}")
        return jsonify({"error": "An error occurred while processing your message"}), 500

@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    try:
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
            
        audio_file = request.files['audio']
        
        # Save the uploaded file to a temporary location
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_audio:
            audio_file.save(temp_audio.name)
            temp_path = temp_audio.name
        
        # Use Whisper to transcribe
        if whisper_model:
            result = whisper_api.transcribe(whisper_model, temp_path, language="id")
            transcription = result.get("text", "")
            
            # Clean up the temporary file
            os.unlink(temp_path)
            
            if not transcription:
                return jsonify({"error": "Failed to transcribe audio", "details": result.get("error", "")}), 500
                
            return jsonify({"transcription": transcription})
        else:
            return jsonify({"error": "Whisper model not available"}), 500
            
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        return jsonify({"error": "An error occurred during transcription"}), 500

@app.route('/api/upload', methods=['POST'])
def upload_file():
    try:
        if 'file' not in request.files:
            return jsonify({"error": "No file provided"}), 400
            
        uploaded_file = request.files['file']
        
        if uploaded_file.filename == '':
            return jsonify({"error": "No file selected"}), 400
            
        # Create uploads directory if it doesn't exist
        upload_dir = os.path.join(os.path.dirname(__file__), 'uploads')
        if not os.path.exists(upload_dir):
            os.makedirs(upload_dir)
        
        # Save the file with a unique name
        file_ext = os.path.splitext(uploaded_file.filename)[1]
        unique_filename = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(upload_dir, unique_filename)
        
        uploaded_file.save(file_path)
        
        # Process the file based on its type
        file_type = os.path.splitext(uploaded_file.filename)[1].lower()
        
        if file_type in ['.jpg', '.jpeg', '.png']:
            # For image files, we'll return a generic response since DeepSeek doesn't have image analysis
            response_text = f"Saya telah menerima gambar '{uploaded_file.filename}'. Silakan jelaskan apa yang ingin Anda ketahui tentang gambar ini, dan saya akan mencoba membantu berdasarkan deskripsi Anda."
        elif file_type in ['.pdf', '.doc', '.docx', '.txt']:
            # Process document file
            response_text = f"Dokumen '{uploaded_file.filename}' telah diterima. Silakan jelaskan apa yang ingin Anda ketahui tentang dokumen ini."
        else:
            # Handle other file types
            response_text = f"File '{uploaded_file.filename}' telah diterima. Silakan jelaskan apa yang ingin Anda ketahui tentang file ini."
            
        return jsonify({
            "message": "File uploaded successfully",
            "filename": uploaded_file.filename,
            "file_path": file_path,
            "response": response_text
        })
            
    except Exception as e:
        logger.error(f"File upload error: {e}")
        return jsonify({"error": "An error occurred during file upload"}), 500

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
    app.run(host='0.0.0.0', port=8080, debug=True)
    # http_server = WSGIServer(('0.0.0.0', 5000), app)
    # http_server.serve_forever()

