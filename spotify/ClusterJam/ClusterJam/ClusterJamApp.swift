import SwiftUI
import FirebaseAppCheck
import GoogleMobileAds
import FirebaseCore
import FirebaseAuth
import SpotifyiOS

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
        
        // Set up Firebase App Check provider factory
        AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
        
        FirebaseApp.configure()
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return SpotifyAuthManager.shared.sessionManager.application(app, open: url, options: options)
    }
}

@main
struct ClusterJamApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var playlistManager = PlaylistManager()
    @StateObject private var spotifyAuthManager = SpotifyAuthManager.shared
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 4/255, green: 4/255, blue: 62/255, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(playlistManager)
                .environmentObject(spotifyAuthManager)
        }
    }
}
