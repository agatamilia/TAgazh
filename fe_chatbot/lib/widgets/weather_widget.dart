import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../models/weather_data.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({Key? key}) : super(key: key);

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  final ApiService _apiService = ApiService();
  WeatherState _state = WeatherState.loading;
  WeatherData? _weatherData;
  String _locationName = 'Mendeteksi lokasi...';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      setState(() {
        _state = WeatherState.loading;
        _errorMessage = '';
      });

      // Step 1: Get device location
      final location = await LocationService.getCurrentPosition();
      
      if (location == null) {
        throw Exception('Tidak bisa mendapatkan lokasi perangkat');
      }

      // Step 2: Get place name
      final placeName = await LocationService.getPlaceFromCoordinates(
        location.latitude!,
        location.longitude!,
      );
      
      // Step 3: Get weather data
      final weather = await _apiService.getWeather(
        location.latitude!,
        location.longitude!,
      );

      setState(() {
        _locationName = placeName ?? 'Lokasi tidak diketahui';
        _weatherData = weather;
        _state = WeatherState.loaded;
      });
      
    } catch (e) {
      print('Error fetching weather: $e');
      setState(() {
        _errorMessage = 'Gagal memuat data cuaca';
        _state = WeatherState.error;
        
        // Set mock data as fallback
        _locationName = 'Jakarta';
        _weatherData = WeatherData(
          temperature: 30.0,
          condition: 'sunny',
          description: 'Cerah',
          location: 'Jakarta',
          advice: 'Cocok untuk panen',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          _locationName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                _buildWeatherStatusIndicator(),
              ],
            ),
            const SizedBox(height: 8),
            _buildWeatherContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherStatusIndicator() {
    switch (_state) {
      case WeatherState.loading:
        return const CircularProgressIndicator(strokeWidth: 2);
      case WeatherState.error:
        return Icon(Icons.error_outline, color: Colors.red[400]);
      case WeatherState.loaded:
        return _buildWeatherIcon(_weatherData!.condition);
    }
  }

  Widget _buildWeatherContent() {
    if (_state == WeatherState.error) {
      return Row(
        children: [
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(color: Colors.red[400]),
            ),
          ),
          TextButton(
            onPressed: _fetchWeather,
            child: const Text('Coba Lagi'),
          ),
        ],
      );
    }

    if (_state == WeatherState.loading) {
      return const LinearProgressIndicator();
    }

    return Row(
      children: [
        Text(
          '${_weatherData?.temperature.round() ?? '--'}°C',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${_weatherData?.description ?? ''} - ${_weatherData?.advice ?? ''}',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherIcon(String condition) {
    final iconData = switch (condition) {
      'sunny' => Icons.wb_sunny,
      'cloudy' => Icons.cloud,
      'rainy' => Icons.umbrella,
      _ => Icons.device_unknown,
    };

    final color = switch (condition) {
      'sunny' => Colors.amber,
      'cloudy' => Colors.blueGrey,
      'rainy' => Colors.blue,
      _ => Colors.grey,
    };

    return Icon(iconData, color: color, size: 28);
  }
}

enum WeatherState { loading, loaded, error }