from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
import os
import requests
import uuid
from datetime import datetime
from werkzeug.utils import secure_filename
import subprocess
from dotenv import load_dotenv
import whisper
import logging
from flask_ngrok import run_with_ngrok

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)

# Database configuration
app.config['SQLALCHEMY_DATABASE_URI'] = f"sqlite:///{os.path.join(os.path.dirname(__file__), 'chatbot.db')}"
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# API Keys
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")

# File upload configuration
UPLOAD_FOLDER = 'uploads/audio'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
MAX_AUDIO_DURATION = 30  # seconds
MIN_AUDIO_DURATION = 0.5  # seconds

# Database Models
class Session(db.Model):
    __tablename__ = 'sessions'
    
    id = db.Column(db.String(36), primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.BigInteger, nullable=False)
    updated_at = db.Column(db.BigInteger, nullable=False)
    
    messages = db.relationship('Message', backref='session', lazy=True, cascade='all, delete-orphan')

class Message(db.Model):
    __tablename__ = 'messages'
    
    id = db.Column(db.String(36), primary_key=True)
    session_id = db.Column(db.String(36), db.ForeignKey('sessions.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    role = db.Column(db.String(20), nullable=False)
    timestamp = db.Column(db.BigInteger, nullable=False)
    image_path = db.Column(db.String(255))
    audio_path = db.Column(db.String(255))

# Whisper model initialization
try:
    WHISPER_MODEL = whisper.load_model("base")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    WHISPER_MODEL = None

# Create database tables
with app.app_context():
    db.create_all()

@app.route('/info', methods=['POST'])
def handle_info():
    try:
        # Get form data
        name = request.form.get('name')
        date = request.form.get('date')
        
        # Handle single file
        single_file = request.files.get('file')
        if single_file:
            single_filename = secure_filename(single_file.filename)
            single_file.save(os.path.join(UPLOAD_FOLDER, single_filename))
        
        # Handle multiple files
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
        # Save file
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

# Session management endpoints
@app.route('/api/sessions', methods=['GET'])
def get_sessions():
    try:
        sessions = Session.query.order_by(Session.updated_at.desc()).all()
        return jsonify([{
            "id": session.id,
            "name": session.name,
            "created_at": session.created_at,
            "updated_at": session.updated_at
        } for session in sessions])
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
        
        new_session = Session(
            id=session_id,
            name=name,
            created_at=current_time,
            updated_at=current_time
        )
        
        db.session.add(new_session)
        db.session.commit()
        
        return jsonify({
            "id": session_id,
            "name": name,
            "created_at": current_time,
            "updated_at": current_time
        })
    except Exception as e:
        logger.error(f"Error creating session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to create session"}), 500

@app.route('/api/sessions/<session_id>', methods=['PUT'])
def update_session(session_id):
    try:
        data = request.json
        name = data.get('name')
        
        if not name:
            return jsonify({"error": "Name is required"}), 400
        
        session = Session.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        current_time = int(datetime.now().timestamp() * 1000)
        session.name = name
        session.updated_at = current_time
        
        db.session.commit()
        
        return jsonify({"message": "Session updated successfully"})
    except Exception as e:
        logger.error(f"Error updating session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to update session"}), 500

@app.route('/api/sessions/<session_id>', methods=['DELETE'])
def delete_session(session_id):
    try:
        session = Session.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        db.session.delete(session)
        db.session.commit()
        
        return jsonify({"message": "Session deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting session: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to delete session"}), 500

# Message management endpoints
@app.route('/api/sessions/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    try:
        messages = Message.query.filter_by(session_id=session_id).order_by(Message.timestamp.asc()).all()
        return jsonify([{
            "id": message.id,
            "session_id": message.session_id,
            "content": message.content,
            "role": message.role,
            "timestamp": message.timestamp,
            "image_path": message.image_path
        } for message in messages])
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
        
        # Check if session exists
        session = Session.query.get(session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404
        
        message_id = str(uuid.uuid4())
        current_time = int(datetime.now().timestamp() * 1000)
        
        new_message = Message(
            id=message_id,
            session_id=session_id,
            content=content,
            role=role,
            timestamp=current_time,
            image_path=image_path,
            audio_path=f"/uploads/audio/{filename}"
        )
        
        # Update session's updated_at timestamp
        session.updated_at = current_time
        
        db.session.add(new_message)
        db.session.commit()
        
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
        db.session.rollback()
        return jsonify({"error": "Failed to save message"}), 500

@app.route('/api/sessions/<session_id>/messages/<message_id>', methods=['DELETE'])
def delete_message(session_id, message_id):
    try:
        message = Message.query.filter_by(id=message_id, session_id=session_id).first()
        if not message:
            return jsonify({"error": "Message not found"}), 404
        
        db.session.delete(message)
        db.session.commit()
        
        return jsonify({"message": "Message deleted successfully"})
    except Exception as e:
        logger.error(f"Error deleting message: {e}")
        db.session.rollback()
        return jsonify({"error": "Failed to delete message"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['DELETE'])
def clear_messages(session_id):
    try:
        Message.query.filter_by(session_id=session_id).delete()
        db.session.commit()
        
        return jsonify({"message": "All messages cleared successfully"})
    except Exception as e:
        logger.error(f"Error clearing messages: {e}")
        db.session.rollback()
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
                    session = Session.query.get(session_id)
                    if not session:
                        return jsonify({"error": "Session not found"}), 404
                    
                    current_time = int(datetime.now().timestamp() * 1000)
                    
                    # Save user message
                    user_message = Message(
                        id=str(uuid.uuid4()),
                        session_id=session_id,
                        content=message,
                        role='user',
                        timestamp=current_time
                    )
                    
                    # Save assistant message
                    assistant_message = Message(
                        id=str(uuid.uuid4()),
                        session_id=session_id,
                        content=formatted_message,
                        role='assistant',
                        timestamp=current_time + 1  # Ensure ordering
                    )
                    
                    # Update session timestamp
                    session.updated_at = current_time
                    
                    db.session.add_all([user_message, assistant_message])
                    db.session.commit()
                except Exception as e:
                    logger.error(f"Error saving messages to database: {e}")
                    db.session.rollback()
            
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

@app.route('/uploads/audio/<filename>')
def serve_audio(filename):
    return send_from_directory(UPLOAD_FOLDER, filename)

def load_whisper_model():
    try:
        model = whisper.load_model("base")
        
        # Validate model
        test_result = model.transcribe("test_audio.wav", language="id", verbose=False)
        if not test_result.get("text"):
            raise RuntimeError("Model test failed")
            
        return model
    except Exception as e:
        logger.error(f"Failed to load Whisper model: {str(e)}")
        return None

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
        response.raise_for_status()
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

def get_deepseek_response(prompt):
    """Get response from DeepSeek API"""
    try:
        headers = {
            "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
            "Content-Type": "application/json"
        }
        
        payload = {
            "model": "deepseek-chat",
            "messages": [
                {"role": "system", "content": "Anda adalah asisten pertanian PeTaniku."},
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        }
        
        response = requests.post(
            "https://api.deepseek.com/v1/chat/completions",
            headers=headers,
            json=payload
        )
        
        if response.status_code == 200:
            result = response.json()
            return result['choices'][0]['message']['content']
        else:
            logger.error(f"DeepSeek API error: {response.text}")
            return "Maaf, saya tidak bisa memberikan jawaban saat ini."
            
    except Exception as e:
        logger.error(f"Error getting DeepSeek response: {e}")
        return "Maaf, terjadi kesalahan dalam memproses permintaan Anda."

if __name__ == '__main__':
    app.run()