import SwiftUI
import FirebaseAuth
import SpotifyiOS

class SpotifyAuthManager: NSObject, ObservableObject, SPTSessionManagerDelegate {
    static let shared = SpotifyAuthManager()
    
    @Published var isAuthorized = false
    private let clientID = "aae4c2a669614b4dbdc085c341fe3d11"
    private let redirectURI = URL(string: "clusterjam://callback")!
    
    private lazy var configuration: SPTConfiguration = {
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.playURI = ""
        return configuration
    }()
    
    lazy var sessionManager: SPTSessionManager = {
        let manager = SPTSessionManager(configuration: configuration, delegate: self)
        return manager
    }()
    
    private var accessToken: String? {
        didSet {
            if let accessToken = accessToken {
                UserDefaults.standard.set(accessToken, forKey: "SpotifyAccessToken")
                DispatchQueue.main.async {
                    self.isAuthorized = true
                }
            } else {
                UserDefaults.standard.removeObject(forKey: "SpotifyAccessToken")
                DispatchQueue.main.async {
                    self.isAuthorized = false
                }
            }
        }
    }
    
    private override init() {
        super.init()
        if let accessToken = UserDefaults.standard.string(forKey: "SpotifyAccessToken") {
            self.accessToken = accessToken
            self.isAuthorized = true
        }
    }
    
    func authenticateWithSpotify() {
        let scope: SPTScope = [.userReadEmail, .userReadPrivate, .userReadPlaybackState, .userModifyPlaybackState, .playlistModifyPublic, .playlistModifyPrivate]
        sessionManager.initiateSession(with: scope, options: .default, campaign: "ClusterJam")
    }
    
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        DispatchQueue.main.async {
            self.accessToken = session.accessToken
            self.isAuthorized = true
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("Failed to authenticate with Spotify: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.isAuthorized = false
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("Session renewed")
        DispatchQueue.main.async {
            self.accessToken = session.accessToken
            self.isAuthorized = true
        }
    }
    
    func unlinkSpotifyAccount() {
        DispatchQueue.main.async {
            self.isAuthorized = false
            self.accessToken = nil
        }
    }
    
    func createSpotifyPlaylist(name: String, tracks: [Song], completion: @escaping (Result<String, Error>) -> Void) {
        guard let accessToken = accessToken else {
            completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not authenticated with Spotify"])))
            return
        }
        
        getUserProfile(accessToken: accessToken) { result in
            switch result {
            case .success(let userID):
                self.createPlaylist(accessToken: accessToken, userID: userID, name: name) { result in
                    switch result {
                    case .success(let playlistID):
                        self.addTracksToPlaylist(accessToken: accessToken, playlistID: playlistID, tracks: tracks) { result in
                            switch result {
                            case .success:
                                completion(.success(playlistID))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func getUserProfile(accessToken: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let userID = json["id"] as? String {
                    completion(.success(userID))
                } else {
                    completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse user ID"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func createPlaylist(accessToken: String, userID: String, name: String, completion: @escaping (Result<String, Error>) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/users/\(userID)/playlists")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["name": name, "public": false]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let playlistID = json["id"] as? String {
                    completion(.success(playlistID))
                } else {
                    completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse playlist ID"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    private func addTracksToPlaylist(accessToken: String, playlistID: String, tracks: [Song], completion: @escaping (Result<Void, Error>) -> Void) {
        let url = URL(string: "https://api.spotify.com/v1/playlists/\(playlistID)/tracks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let uris = tracks.compactMap { URL(string: $0.trackUri)?.absoluteString }
        let body: [String: Any] = ["uris": uris]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "SpotifyAuthManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                let error = NSError(domain: "SpotifyAuthManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to add tracks to playlist"])
                completion(.failure(error))
            }
        }.resume()
    }
}

struct AccountView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var spotifyAuthManager: SpotifyAuthManager
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var isSkipped = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "person.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundColor(Color(red: 4/255, green: 4/255, blue: 62/255))
                
                Text(Auth.auth().currentUser?.email ?? "Not Logged In")
                    .font(.title)
                    .fontWeight(.semibold)
                
                if spotifyAuthManager.isAuthorized {
                    Text("Synced with Spotify")
                        .foregroundColor(.green)
                        .font(.subheadline)
                    
                    Button(action: {
                        spotifyAuthManager.unlinkSpotifyAccount()
                    }) {
                        Text("Unlink Spotify")
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                } else {
                    Button(action: {
                        spotifyAuthManager.authenticateWithSpotify()
                    }) {
                        Text("Sync Spotify Account")
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                
                if Auth.auth().currentUser != nil {
                    Button(action: {
                        showingSignOutAlert = true
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color(red: 151/255, green: 219/255, blue: 226/255))
                            .cornerRadius(10)
                    }
                } else {
                    NavigationLink(destination: SignInView(isSkipped: $isSkipped)) {
                        Text("Sign In")
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color(red: 151/255, green: 219/255, blue: 226/255))
                            .cornerRadius(10)
                    }
                }
                
                NavigationLink(destination: AboutView()) {
                    Text("About")
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(Color(red: 4/255, green: 4/255, blue: 62/255))
                        .cornerRadius(10)
                }
                
                if Auth.auth().currentUser != nil {
                    Button(action: {
                        showingDeleteAccountAlert = true
                    }) {
                        Text("Delete Account")
                            .foregroundColor(.white)
                            .frame(width: 200)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                Spacer()
            }
            .alert(isPresented: $showingSignOutAlert) {
                Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) {
                        signOut()
                    },
                    secondaryButton: .cancel()
                )
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            authManager.isSignedIn = false
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    func deleteAccount() {
        let user = Auth.auth().currentUser
        
        user?.delete { error in
            if let error = error {
                print("Error deleting account: \(error.localizedDescription)")
            } else {
                authManager.isSignedIn = false
            }
        }
    }
}


struct AboutView: View {
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("ClusterJam")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                    
                    Text("Have you ever discovered a new artist or want to re-listen to one of your favorite artists but then get overwhelmed by the amount of songs they have and don't know where to start?")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Text("ClusterJam is an app that helps you discover music by clustering songs based on their audio features. We simplify the process of finding songs to add to your playlists from your favorite artists. Explore different clusters to find songs that match your mood and preference.")
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    NavigationLink(destination: GeekView()) {
                        Text("For the Geeks ->")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color(red: 4/255, green: 4/255, blue: 62/255))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(minHeight: geometry.size.height)
            }
            .frame(width: geometry.size.width)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 151/255, green: 219/255, blue: 226/255), Color(red: 4/255, green: 4/255, blue: 62/255)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .edgesIgnoringSafeArea(.all)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GeekView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("How ClusterJam Works")
                    .font(.largeTitle)
                    .padding(.bottom)
                
                Text("""
ClusterJam uses the Spotify API to fetch detailed audio features for each song. These features include danceability, energy, key, loudness, mode, speechiness, acousticness, instrumentalness, liveness, valence, and tempo.

Here's a step-by-step overview of the process:

1. **Fetching Data**:
    - We retrieve the artist's albums and tracks using the Spotify API.
    - For each track, we obtain audio features that describe the characteristics of the song.

2. **Data Preprocessing**:
    - We normalize the audio feature values to ensure they are on a comparable scale.

3. **Clustering**:
    - We use the K-Means algorithm to cluster the songs into different groups based on their audio features.
    - Each cluster represents a different mood, style, or season.

4. **Displaying Results**:
    - The clustered songs are then displayed in the app, allowing users to explore songs by different moods and preferences.
""")
                .padding(.bottom)
                
                Text("Technologies Used")
                    .font(.title2)
                    .padding(.bottom)
                
                Text("""
- **SwiftUI**: For building the app's user interface.
- **Spotify Web API**: For retrieving music data and audio features.
- **Scikit-Learn**: For the K-means algorithm to group songs into different clusters.
- **Python**: For the backend clustering.
""")
            }
            .padding()
        }
        .navigationTitle("For the Geeks")
    }
}
