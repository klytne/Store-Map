import Flutter
import UIKit
import GoogleMaps 

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Google Maps API key
    GMSServices.provideAPIKey("AIzaSyCd5u_-oxxOXq1moqCSN06bzY44JSbRc_g") 

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
