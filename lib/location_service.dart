import 'package:geolocator/geolocator.dart';

class LocationService {
  static const double allowedLatitude = 3.7660435104353476;
  static const double allowedLongitude = 98.68209301040406;
  static const double defaultAllowedDistance = 150.0;

  final List<Position> _lastPositions = [];
  static const int _maxHistory = 5; // Maksimal pembacaan lokasi yang disimpan

  Future<bool> isWithinAllowedLocation(
      {double radius = defaultAllowedDistance}) async {
    try {
      // Memeriksa izin lokasi
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever) {
          print('Izin lokasi ditolak secara permanen');
          return false;
        }
      }

      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        print('Izin lokasi belum diberikan.');
        return false;
      }

      // Mengatur akurasi lokasi dan jarak filter
      LocationSettings locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10, // Update setiap 10 meter
      );

      // Mendapatkan lokasi saat ini
      Position position = await Geolocator.getCurrentPosition(
          locationSettings: locationSettings);

      // Menyimpan pembacaan lokasi terakhir
      _lastPositions.add(position);
      if (_lastPositions.length > _maxHistory) {
        _lastPositions.removeAt(
            0); // Hapus pembacaan terlama jika sudah melebihi maksimal
      }

      // Menghitung rata-rata lokasi
      double averageLatitude =
          _lastPositions.map((p) => p.latitude).reduce((a, b) => a + b) /
              _lastPositions.length;
      double averageLongitude =
          _lastPositions.map((p) => p.longitude).reduce((a, b) => a + b) /
              _lastPositions.length;

      // Menghitung jarak antara lokasi saat ini dengan lokasi yang diizinkan
      double distanceInMeters = Geolocator.distanceBetween(
        averageLatitude,
        averageLongitude,
        allowedLatitude,
        allowedLongitude,
      );

      print('Posisi rata-rata saat ini: ($averageLatitude, $averageLongitude)');
      print('Jarak ke lokasi yang diizinkan: $distanceInMeters meter');

      return distanceInMeters <= radius;
    } catch (e) {
      print('Error mendapatkan lokasi: $e');
      return false;
    }
  }
}
