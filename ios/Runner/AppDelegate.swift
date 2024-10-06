import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  var locationManager: CLLocationManager?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Inisialisasi CLLocationManager
    locationManager = CLLocationManager()
    locationManager?.delegate = self
    locationManager?.requestWhenInUseAuthorization() // Meminta izin lokasi saat digunakan

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Delegate method untuk memantau perubahan status izin lokasi
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .denied:
      print("Izin lokasi ditolak.")
    case .authorizedWhenInUse, .authorizedAlways:
      print("Izin lokasi diberikan.")
    default:
      print("Menunggu izin lokasi...")
    }
  }
}
