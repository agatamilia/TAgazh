from flask import Flask, json, request, jsonify, send_from_directory
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
from flask_cors import CORS
from flask_migrate import Migrate

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
run_with_ngrok(app)
CORS(app)

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

migrate = Migrate(app, db)

# Whisper model initialization
try:
    WHISPER_MODEL = whisper.load_model("base")
    logging.info("Whisper model loaded successfully")
except Exception as e:
    logging.error(f"Failed to load Whisper model: {e}")
    WHISPER_MODEL = None

with app.app_context():
    db.drop_all()  # WARNING: Deletes all data!
    db.create_all()

if not os.access(UPLOAD_FOLDER, os.W_OK):
    logger.error(f"Upload folder not writable: {UPLOAD_FOLDER}")




@app.route('/api/transcribe', methods=['POST'])
def transcribe_audio():
    if 'audio' not in request.files:
        return jsonify({"error": "No audio file provided"}), 400

    audio_file = request.files['audio']
    if audio_file.filename == '':
        return jsonify({"error": "Empty filename"}), 400

    try:
        # Save file
        filename = f"audio_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}.wav"
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
            
        session_id = request.form.get('session_id')
        if session_id:
            try:
                current_time = int(datetime.now().timestamp() * 1000)
                
                # Save user audio message
                user_message = Message(
                    id=str(uuid.uuid4()),
                    session_id=session_id,
                    content=transcription,
                    role='user',
                    timestamp=current_time,
                    audio_path=f"/uploads/audio/{filename}"
                )
                
                # Save assistant response
                assistant_message = Message(
                    id=str(uuid.uuid4()),
                    session_id=session_id,
                    content=ai_response,
                    role='assistant',
                    timestamp=current_time + 1
                )
                
                # Update session
                session = db.session.get(Session, session_id)
                if session:
                    session.updated_at = current_time
                    db.session.add_all([user_message, assistant_message])
                    db.session.commit()
            except Exception as e:
                logger.error(f"Error saving transcribed messages: {e}")
                db.session.rollback()

        return jsonify({
            "status": "success",
            "transcription": transcription,
            "ai_response": ai_response,
            "audio_url": f"/uploads/audio/{filename}"
        })

    except Exception as e:
        logging.error(f"Transcription error: {str(e)}")
        return jsonify({"error": "Audio processing failed"}), 500

# @app.route('/api/transcribe', methods=['POST'])
# def transcribe_audio():
#     if 'audio' not in request.files:
#         return jsonify({"error": "No audio file provided"}), 400

#     audio_file = request.files['audio']
#     if audio_file.filename == '':
#         return jsonify({"error": "Empty filename"}), 400

#     try:
#         # Create upload directory if needed
#         os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        
#         # Generate unique filename
#         filename = secure_filename(f"audio_{datetime.now().timestamp()}.wav")
#         filepath = os.path.join(UPLOAD_FOLDER, filename)
        
#         # Save file
#         audio_file.save(filepath)
        
#         # Verify file was saved
#         if not os.path.exists(filepath):
#             return jsonify({"error": "Failed to save audio file"}), 500

#         # Process with Whisper
#         result = WHISPER_MODEL.transcribe(filepath, language="id")
#         transcription = result.get("text", "").strip()
        
#         if not transcription:
#             return jsonify({"error": "No speech detected"}), 400

#         return jsonify({
#             "status": "success",
#             "transcription": transcription,
#             "audio_url": f"/uploads/audio/{filename}"
#         })

#     except Exception as e:
#         logging.error(f"Transcription error: {str(e)}")
#         return jsonify({"error": "Audio processing failed"}), 500

# @app.route('/api/sessions/<session_id>/messages', methods=['POST'])
# def save_message(session_id):
#     try:
#         data = request.json
#         if not data:
#             return jsonify({"error": "No data provided"}), 400

#         # Validate required fields
#         required_fields = ['content', 'role']
#         if not all(field in data for field in required_fields):
#             return jsonify({"error": f"Missing required fields: {required_fields}"}), 400

#         # Check if session exists
#         session = db.session.get(Session, session_id)
#         if not session:
#             return jsonify({"error": "Session not found"}), 404

#         # Create message with proper timestamp
#         message = Message(
#             id=str(uuid.uuid4()),
#             session_id=session_id,
#             content=data['content'],
#             role=data['role'],
#             timestamp=int(datetime.now().timestamp() * 1000),
#             image_path=data.get('image_path'),
#             audio_path=data.get('audio_path')
#         )

#         # Update session timestamp
#         session.updated_at = int(datetime.now().timestamp() * 1000)

#         # Add to database session
#         db.session.add(message)
        
#         # Commit transaction
#         db.session.commit()

#         return jsonify({
#             "id": message.id,
#             "session_id": message.session_id,
#             "content": message.content,
#             "role": message.role,
#             "timestamp": message.timestamp,
#             "image_path": message.image_path,
#             "audio_path": message.audio_path
#         }), 201

#     except Exception as e:
#         db.session.rollback()
#         logger.error(f"Error saving message: {str(e)}", exc_info=True)
#         return jsonify({
#             "error": "Failed to save message",
#             "details": str(e)
#         }), 500   

    
def validate_audio_file(filepath):
    """Validasi format dan durasi audio"""
    try:
        # Cek apakah file ada
        if not os.path.exists(filepath):
            return {"error": "File not found"}
            
        # Cek ukuran file minimal (100 bytes)
        if os.path.getsize(filepath) < 100:
            return {"error": "File too small (corrupted?)"}
        
        # Validasi dengan ffprobe
        result = subprocess.run([
            'ffprobe', '-v', 'error',
            '-show_entries', 'stream=codec_type,sample_rate,channels',
            '-of', 'json',
            filepath
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            return {"error": "Invalid audio file", "details": result.stderr}
            
        # Parse output ffprobe
        probe_data = json.loads(result.stdout)
        streams = probe_data.get('streams', [])
        
        if not any(s.get('codec_type') == 'audio' for s in streams):
            return {"error": "No audio stream found"}
            
        # Cek sample rate dan channels
        for stream in streams:
            if stream.get('codec_type') == 'audio':
                if int(stream.get('sample_rate', 0)) < 8000:
                    return {"error": "Sample rate too low (min 8kHz)"}
                if int(stream.get('channels', 0)) < 1:
                    return {"error": "No audio channels"}
                    
        return {"valid": True}
        
        
    except json.JSONDecodeError:
        return {"error": "Invalid JSON response from ffprobe"}
    except Exception as e:
        return {"error": f"Validation error: {str(e)}"}
    
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
        
        session = db.session.get(Session, session_id)
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
        session = db.session.get(Session, session_id)
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
# @app.route('/api/sessions/<session_id>/messages', methods=['GET'])
# def get_messages(session_id):
#     try:
#         messages = Message.query.filter_by(session_id=session_id).order_by(Message.timestamp.asc()).all()
#         return jsonify([{
#             "id": message.id,
#             "session_id": message.session_id,
#             "content": message.content,
#             "role": message.role,
#             "timestamp": message.timestamp,
#             "image_path": message.image_path
#         } for message in messages])
#     except Exception as e:
#         logger.error(f"Error getting messages: {e}")
#         return jsonify({"error": "Failed to get messages"}), 500

@app.route('/api/sessions/<session_id>/messages', methods=['GET'])
def get_messages(session_id):
    try:
        messages = Message.query.filter_by(session_id=session_id)\
                              .order_by(Message.timestamp.asc())\
                              .all()
        
        return jsonify([{
            "id": msg.id,
            "session_id": msg.session_id,
            "content": msg.content,
            "role": msg.role,
            "timestamp": msg.timestamp,
            "image_path": msg.image_path,
            "audio_path": msg.audio_path  # This will now work after migration
        } for msg in messages])
    except Exception as e:
        logger.error(f"Error getting messages: {e}")
        return jsonify({"error": "Failed to get messages"}), 500
    
@app.route('/api/sessions/<session_id>/messages', methods=['POST'])
def save_message(session_id):
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No data provided"}), 400

        # Validate required fields
        required_fields = ['content', 'role']
        if not all(field in data for field in required_fields):
            return jsonify({"error": f"Missing required fields: {required_fields}"}), 400

        # Get session
        session = db.session.get(Session, session_id)
        if not session:
            return jsonify({"error": "Session not found"}), 404

        # Create message
        message = Message(
            id=str(uuid.uuid4()),
            session_id=session_id,
            content=data['content'],
            role=data['role'],
            timestamp=int(datetime.now().timestamp() * 1000),
            image_path=data.get('image_path'),
            audio_path=data.get('audio_path')
        )

        # Update session
        session.updated_at = int(datetime.now().timestamp() * 1000)

        db.session.add(message)
        db.session.commit()

        return jsonify({
            "id": message.id,
            "session_id": session_id,
            "content": message.content,
            "role": message.role,
            "timestamp": message.timestamp,
            "image_path": message.image_path,
            "audio_path": message.audio_path
        }), 201

    except Exception as e:
        db.session.rollback()
        logger.error(f"Error saving message: {str(e)}")
        return jsonify({"error": "Failed to save message", "details": str(e)}), 500
    
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
                    session = db.session.get(Session, session_id)
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