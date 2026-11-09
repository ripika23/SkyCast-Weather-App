import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SkyCastApp());
}

// ============================================================
// SKYCAST ULTIMATE
// Live Weather & Intelligent Forecast Application
// Powered by Open-Meteo API
// ============================================================

class SkyCastApp extends StatelessWidget {
  const SkyCastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyCast | Weather Reimagined',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFF10182F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF829DFF),
          brightness: Brightness.dark,
        ),
      ),
      home: const WeatherHomePage(),
    );
  }
}

// ============================================================
// APP CONSTANTS
// ============================================================

class AppColors {
  static const background = Color(0xFF10182F);
  static const surface = Color(0xFF1B2746);
  static const primary = Color(0xFF829DFF);
  static const secondary = Color(0xFF526DD0);
  static const white = Colors.white;
  static const muted = Color(0xFFA5B0C9);
  static const success = Color(0xFF72E2AC);
}

// ============================================================
// WEATHER MODELS
// ============================================================

class WeatherLocation {
  final String name;
  final String country;
  final double latitude;
  final double longitude;

  const WeatherLocation({
    required this.name,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: json['name'] as String,
      country: json['country'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class ForecastDay {
  final DateTime date;
  final double minimum;
  final double maximum;
  final int weatherCode;
  final int rainProbability;

  const ForecastDay({
    required this.date,
    required this.minimum,
    required this.maximum,
    required this.weatherCode,
    required this.rainProbability,
  });
}

class WeatherData {
  final WeatherLocation location;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final DateTime observationTime;
  final List<ForecastDay> forecast;

  const WeatherData({
    required this.location,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.observationTime,
    required this.forecast,
  });
}

// ============================================================
// API SERVICE
// ============================================================

class WeatherService {
  static const Duration timeout = Duration(seconds: 20);

  static Future<List<WeatherLocation>> searchCity(
    String city,
  ) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': city,
        'count': '5',
        'language': 'en',
        'format': 'json',
      },
    );

    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Unable to search for this city.');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid location response.');
    }

    final results = data['results'];

    if (results == null || results is! List || results.isEmpty) {
      throw Exception('No matching city was found.');
    }

    return results
        .whereType<Map<String, dynamic>>()
        .map(WeatherLocation.fromJson)
        .toList();
  }

  static Future<WeatherData> fetchWeather(
    WeatherLocation location,
  ) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,relative_humidity_2m,'
            'apparent_temperature,is_day,weather_code,'
            'wind_speed_10m',
        'daily': 'weather_code,temperature_2m_max,'
            'temperature_2m_min,precipitation_probability_max',
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'timezone': 'auto',
        'forecast_days': '6',
      },
    );

    final response = await http.get(uri).timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('Weather service is temporarily unavailable.');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid weather response.');
    }

    final current = data['current'];
    final daily = data['daily'];

    if (current is! Map<String, dynamic> || daily is! Map<String, dynamic>) {
      throw Exception('Weather information is incomplete.');
    }

    final times = daily['time'];
    final minimums = daily['temperature_2m_min'];
    final maximums = daily['temperature_2m_max'];
    final codes = daily['weather_code'];
    final rain = daily['precipitation_probability_max'];

    if (times is! List ||
        minimums is! List ||
        maximums is! List ||
        codes is! List ||
        rain is! List) {
      throw Exception('Forecast information is incomplete.');
    }

    final count = [
      times.length,
      minimums.length,
      maximums.length,
      codes.length,
      rain.length,
    ].reduce((a, b) => a < b ? a : b);

    if (count == 0) {
      throw Exception('No forecast information is available.');
    }

    final forecasts = <ForecastDay>[];

    for (int i = 0; i < count; i++) {
      forecasts.add(
        ForecastDay(
          date: DateTime.parse(times[i].toString()),
          minimum: _number(minimums[i]),
          maximum: _number(maximums[i]),
          weatherCode: _integer(codes[i]),
          rainProbability: _integer(rain[i]),
        ),
      );
    }

    return WeatherData(
      location: location,
      temperature: _number(current['temperature_2m']),
      feelsLike: _number(current['apparent_temperature']),
      humidity: _integer(current['relative_humidity_2m']),
      windSpeed: _number(current['wind_speed_10m']),
      weatherCode: _integer(current['weather_code']),
      isDay: _integer(current['is_day']) == 1,
      observationTime: DateTime.parse(
        current['time'].toString(),
      ),
      forecast: forecasts,
    );
  }

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    throw Exception('Invalid numerical weather data.');
  }

  static int _integer(dynamic value) {
    if (value is num) return value.toInt();
    throw Exception('Invalid weather information.');
  }
}

// ============================================================
// WEATHER CONDITION INFORMATION
// WMO WEATHER INTERPRETATION CODES
// ============================================================

class WeatherInfo {
  static String description(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 56:
      case 57:
        return 'Freezing Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rainy';
      case 66:
      case 67:
        return 'Freezing Rain';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Snowfall';
      case 80:
      case 81:
      case 82:
        return 'Rain Showers';
      case 85:
      case 86:
        return 'Snow Showers';
      case 95:
        return 'Thunderstorm';
      case 96:
      case 99:
        return 'Thunderstorm with Hail';
      default:
        return 'Variable Conditions';
    }
  }

  static IconData icon(int code, {bool isDay = true}) {
    if (code == 0) {
      return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
    }

    if (code == 1 || code == 2) {
      return isDay ? Icons.wb_cloudy_rounded : Icons.cloud_circle_rounded;
    }

    if (code == 3) return Icons.cloud_rounded;

    if (code == 45 || code == 48) {
      return Icons.foggy;
    }

    if (code >= 51 && code <= 67) {
      return Icons.grain_rounded;
    }

    if (code >= 71 && code <= 77) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 80 && code <= 82) {
      return Icons.water_drop_rounded;
    }

    if (code == 85 || code == 86) {
      return Icons.ac_unit_rounded;
    }

    if (code >= 95) {
      return Icons.thunderstorm_rounded;
    }

    return Icons.cloud_queue_rounded;
  }
}

// ============================================================
// MAIN WEATHER SCREEN
// ============================================================

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  WeatherData? weather;

  WeatherLocation? selectedLocation;

  final TextEditingController searchController = TextEditingController();

  bool isLoading = false;
  bool isSearching = false;
  bool isCelsius = true;

  String? errorMessage;

  int requestId = 0;

  static const WeatherLocation defaultLocation = WeatherLocation(
    name: 'Bhimavaram',
    country: 'India',
    latitude: 16.5449,
    longitude: 81.5212,
  );

  @override
  void initState() {
    super.initState();

    searchController.text = defaultLocation.name;

    selectedLocation = defaultLocation;

    loadWeather(defaultLocation);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD WEATHER
  // ==========================================================

  Future<void> loadWeather(WeatherLocation location) async {
    final currentRequest = ++requestId;

    setState(() {
      isLoading = true;
      isSearching = false;
      errorMessage = null;
    });

    try {
      final result = await WeatherService.fetchWeather(location);

      if (!mounted || currentRequest != requestId) return;

      setState(() {
        weather = result;
        selectedLocation = location;
        searchController.text = location.name;
        isLoading = false;
      });
    } on TimeoutException {
      if (!mounted || currentRequest != requestId) return;

      setState(() {
        isLoading = false;
        errorMessage = 'The request timed out. Please try again.';
      });
    } catch (e) {
      if (!mounted || currentRequest != requestId) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to retrieve weather information. Check your connection and try again.';
      });
    }
  }

  // ==========================================================
  // SEARCH CITY
  // ==========================================================

  Future<void> searchWeather() async {
    final query = searchController.text.trim();

    if (query.isEmpty) {
      showMessage('Please enter a city name.');
      return;
    }

    FocusScope.of(context).unfocus();

    final currentRequest = ++requestId;

    setState(() {
      isLoading = true;
      isSearching = true;
      errorMessage = null;
    });

    try {
      final locations = await WeatherService.searchCity(query);

      if (!mounted || currentRequest != requestId) return;

      final location = locations.first;

      final result = await WeatherService.fetchWeather(location);

      if (!mounted || currentRequest != requestId) return;

      setState(() {
        weather = result;
        selectedLocation = location;
        searchController.text = location.name;
        isLoading = false;
        isSearching = false;
      });
    } on TimeoutException {
      if (!mounted || currentRequest != requestId) return;

      setState(() {
        isLoading = false;
        isSearching = false;
        errorMessage = 'City search timed out. Please try again.';
      });
    } catch (e) {
      if (!mounted || currentRequest != requestId) return;

      setState(() {
        isLoading = false;
        isSearching = false;
        errorMessage =
            'City not found or weather unavailable. Please check the spelling.';
      });
    }
  }

  // ==========================================================
  // REFRESH CURRENT CITY
  // ==========================================================

  Future<void> refreshWeather() async {
    if (selectedLocation != null) {
      await loadWeather(selectedLocation!);
    }
  }

  // ==========================================================
  // USER FEEDBACK
  // ==========================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  // ==========================================================
  // TEMPERATURE CONVERSION
  // ==========================================================

  double convertTemperature(double value) {
    return isCelsius ? value : (value * 9 / 5) + 32;
  }

  String temperature(double value) {
    return '${convertTemperature(value).round()}°';
  }

  // ==========================================================
  // DATE FORMATTING
  // ==========================================================

  String formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;

    final minute = time.minute.toString().padLeft(2, '0');

    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  // ==========================================================
  // MAIN BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A2B53),
              Color(0xFF10182F),
              Color(0xFF101329),
            ],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: refreshWeather,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeader(),
                  const SizedBox(height: 28),
                  buildSearchBar(),
                  const SizedBox(height: 25),
                  if (isLoading)
                    buildLoading()
                  else if (errorMessage != null)
                    buildError()
                  else if (weather != null) ...[
                    buildLocation(),
                    const SizedBox(height: 20),
                    buildCurrentWeather(),
                    const SizedBox(height: 27),
                    buildWeatherDetails(),
                    const SizedBox(height: 30),
                    buildForecast(),
                    const SizedBox(height: 28),
                    buildFooter(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.cloud_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
                SizedBox(width: 9),
                Text(
                  'SKYCAST',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'WEATHER, REIMAGINED.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              unitButton('°C', true),
              unitButton('°F', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget unitButton(String label, bool celsius) {
    final selected = isCelsius == celsius;

    return GestureDetector(
      onTap: () {
        setState(() {
          isCelsius = celsius;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.background : Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // CITY SEARCH
  // ==========================================================

  Widget buildSearchBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: searchController,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search any city...',
                hintStyle: TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => searchWeather(),
            ),
          ),
          IconButton(
            onPressed: isLoading ? null : searchWeather,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // LOCATION
  // ==========================================================

  Widget buildLocation() {
    return Row(
      children: [
        const Icon(
          Icons.location_on_rounded,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            '${weather!.location.name}, ${weather!.location.country}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Icon(
          Icons.circle,
          color: AppColors.success,
          size: 8,
        ),
        const SizedBox(width: 5),
        const Text(
          'LIVE',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // CURRENT WEATHER CARD
  // ==========================================================

  Widget buildCurrentWeather() {
    final w = weather!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF718FFF),
            Color(0xFF5069C9),
            Color(0xFF34458F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                w.isDay ? 'DAYTIME WEATHER' : 'NIGHTTIME WEATHER',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                w.isDay ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Icon(
            WeatherInfo.icon(
              w.weatherCode,
              isDay: w.isDay,
            ),
            size: 88,
            color: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            temperature(w.temperature),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 76,
              fontWeight: FontWeight.w300,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            WeatherInfo.description(w.weatherCode),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Feels like ${temperature(w.feelsLike)}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 23),
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.22),
          ),
          const SizedBox(height: 17),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: Colors.white70,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Observation: ${formatTime(w.observationTime)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.cloud_done_rounded,
                size: 15,
                color: Colors.white70,
              ),
              const SizedBox(width: 5),
              const Flexible(
                child: Text(
                  'Open-Meteo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // WEATHER DETAILS
  // ==========================================================

  Widget buildWeatherDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WEATHER INSIGHTS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: detailCard(
                Icons.water_drop_rounded,
                'Humidity',
                '${weather!.humidity}%',
                'Moisture in air',
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: detailCard(
                Icons.air_rounded,
                'Wind Speed',
                weather!.windSpeed.toStringAsFixed(1),
                'km/h',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget detailCard(
    IconData icon,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.065),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 25,
          ),
          const SizedBox(height: 15),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SIX-DAY FORECAST
  // ==========================================================

  Widget buildForecast() {
    final forecasts = weather!.forecast;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Flexible(
              child: Text(
                'UPCOMING FORECAST',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${forecasts.length} DAYS',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.055),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: List.generate(
              forecasts.length,
              (index) => forecastTile(
                forecasts[index],
                index,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget forecastTile(ForecastDay item, int index) {
    final date = item.date;

    String day;

    if (index == 0) {
      day = 'Today';
    } else if (index == 1) {
      day = 'Tomorrow';
    } else {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

      day = weekdays[date.weekday - 1];
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Icon(
                  WeatherInfo.icon(item.weatherCode),
                  color: AppColors.primary,
                  size: 23,
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  '${item.rainProbability}% rain',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      temperature(item.maximum),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      temperature(item.minimum),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (index != weather!.forecast.length - 1)
          Divider(
            height: 1,
            color: Colors.white.withOpacity(0.08),
          ),
      ],
    );
  }

  // ==========================================================
  // LOADING EXPERIENCE
  // ==========================================================

  Widget buildLoading() {
    return SizedBox(
      height: 430,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 55,
              width: 55,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSearching ? 'Exploring the skies...' : 'Reading the skies...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            const Text(
              'Fetching weather intelligence',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR EXPERIENCE
  // ==========================================================

  Widget buildError() {
    return SizedBox(
      height: 430,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.primary,
              size: 72,
            ),
            const SizedBox(height: 22),
            const Text(
              'Weather unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () {
                if (selectedLocation != null) {
                  loadWeather(selectedLocation!);
                }
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                padding: const EdgeInsets.symmetric(
                  horizontal: 25,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FOOTER
  // ==========================================================

  Widget buildFooter() {
    return Center(
      child: Column(
        children: [
          const Icon(
            Icons.cloud_done_rounded,
            color: AppColors.primary,
            size: 28,
          ),
          const SizedBox(height: 9),
          const Text(
            'Powered by Open-Meteo',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Smarter forecasts. Better everyday decisions.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'SKYCAST • WEATHER INTELLIGENCE',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 9,
              letterSpacing: 1.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
