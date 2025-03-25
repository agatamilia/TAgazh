from flask import Flask, request, jsonify
import whisper
#import openai
import requests
import os
from dotenv import load_dotenv
import geocoder
import time
from openai import OpenAI

client = OpenAI(
    # This is the default and can be omitted
    api_key=os.environ.get("OPENAI_API_KEY"),
)

# Memuat variabel dari file .env
load_dotenv()

# API keys
OPENWEATHER_API_KEY = os.getenv('OPENWEATHER_API_KEY')
#openai.api_key = os.getenv('OPENAI_API_KEY')

# Inisialisasi Flask dan Whisper model
app = Flask(__name__)
model = whisper.load_model("base")  # Menggunakan model "base" Whisper

# Fungsi untuk mendeteksi bahasa audio dengan Whisper
def detect_language(mel):
    _, probs = model.detect_language(mel)
    return max(probs, key=probs.get)


# Fungsi untuk mentranskripsi audio
def transcribe_audio(audio_path):
    # Load audio dan memangkas jika lebih dari 10 detik
    audio = whisper.load_audio(audio_path)
    audio = whisper.pad_or_trim(audio)
    
    # Membuat log-Mel spectrogram
    mel = whisper.log_mel_spectrogram(audio, n_mels=model.dims.n_mels).to(model.device)
    
    # Deteksi bahasa
    language = detect_language(mel)
    print(f"Detected language: {language}")
    
    # Decode audio
    options = whisper.DecodingOptions(language=language)
    result = whisper.decode(model, mel, options)
    
    # Batasi output teks menjadi 250 kata maksimal
    words = result.text.split()
    if len(words) > 250:
        result.text = " ".join(words[:250])
    
    return result.text


# Fungsi untuk mendapatkan informasi cuaca berdasarkan lokasi
def get_weather():
    try:
        # Mendapatkan lokasi berdasarkan IP
        g = geocoder.ip('me')
        latitude, longitude = g.latlng

        if latitude is None or longitude is None:
            return jsonify({'error': 'Unable to determine location'}), 500

        # Membuat URL untuk permintaan API ke OpenWeatherMap
        url = f"http://api.openweathermap.org/data/2.5/weather?lat={latitude}&lon={longitude}&appid={OPENWEATHER_API_KEY}&units=metric"
        
        # Melakukan permintaan ke OpenWeatherMap API
        response = requests.get(url)
        
        # Mengecek jika respons sukses
        if response.status_code != 200:
            return jsonify({'error': 'Failed to get weather data from OpenWeatherMap'}), 500

        data = response.json()

        # Memastikan bahwa data yang diterima memiliki kunci 'main'
        if "main" not in data:
            return jsonify({'error': 'Weather data format is incorrect or incomplete'}), 500

        main_data = data["main"]
        weather_data = data["weather"][0]

        temperature = main_data["temp"]
        weather_description = weather_data["description"]

        return f"Cuaca saat ini di lokasi Anda: {temperature}°C, {weather_description}"
    
    except Exception as e:
        return jsonify({'error': f'Error: {str(e)}'}), 500

# Fungsi untuk mendapatkan respons dari OpenAI GPT
def get_gpt_response(user_input):
    try:
        # Prompt yang memastikan GPT hanya memberikan jawaban terkait pertanian
        prompt = f"""
        Anda adalah asisten yang ahli dalam pertanian dan perkebunan. Hanya memberikan jawaban yang berhubungan dengan pertanian, perkebunan, dan kegiatan terkait petani. 
        Pertanyaan: {user_input}
        """

        # Menggunakan metode openai.ChatCompletion.create untuk percakapan
        response = client.chat.completions.create(
            model="gpt-3.5-turbo",  # Pilih model yang sesuai (gpt-4 atau gpt-3.5-turbo)
            messages=[
                {"role": "user", "content": prompt}  # Format pesan dengan role "user"
            ],
            max_tokens=150  # Batasi jumlah token dalam respons
        )

        # Mengembalikan teks dari pilihan pertama
        return response.choices[0].message.content

    except Exception as e:
        return f"Error: {str(e)}"

@app.route('/transcribe', methods=['POST'])
def transcribe():
    # Pastikan file audio diterima
    if 'audio' not in request.files:
        return jsonify({'error': 'No audio file provided'}), 400

    audio_file = request.files['audio']
    audio_path = os.path.join("temp", f"{str(time.time())}.mp3")

    # Simpan file audio sementara
    audio_file.save(audio_path)

    try:
        # Transkripsi audio
        transcribed_text = transcribe_audio(audio_path)

        # Hapus file audio sementara
        os.remove(audio_path)

        return jsonify({'text': transcribed_text}), 200

    except Exception as e:
        os.remove(audio_path)  # Hapus file jika terjadi error
        return jsonify({'error': str(e)}), 500


@app.route('/weather', methods=['GET'])
def weather():
    weather_info = get_weather()
    return jsonify({'weather': weather_info}), 200


@app.route('/ask', methods=['POST'])
def ask_gpt():
    user_input = request.json.get('question')  # Mendapatkan input dari permintaan JSON

    if not user_input:
        return jsonify({'error': 'No question provided'}), 400

    response_text = get_gpt_response(user_input)
    return jsonify({'response': response_text}), 200


# Menjalankan server Flask
if __name__ == '__main__':
    if not os.path.exists('temp'):
        os.makedirs('temp')  # Membuat folder untuk menyimpan file audio

    app.run(host='0.0.0.0', port=5000, debug=True)
