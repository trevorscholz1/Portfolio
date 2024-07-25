import SwiftUI
import FirebaseAuth
import AuthenticationServices

class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    
    init() {
        Auth.auth().addStateDidChangeListener { _, user in
            self.isSignedIn = user != nil
        }
    }
}

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var appData = AppData()
    @State private var isSkipped = false
    
    var body: some View {
        Group {
            if authManager.isSignedIn || isSkipped {
                if appData.isLoading {
                    ProgressView("Loading data...")
                } else {
                    MainAppView()
                        .environmentObject(appData)
                }
            } else {
                SignInView(isSkipped: $isSkipped)
            }
        }
        .environmentObject(authManager)
    }
}

struct SignInView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var isCreatingAccount = false
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var isSkipped: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            BannerView()
                .frame(height: 60)
            ZStack {
                Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    Text(isCreatingAccount ? "Create Account" : "Welcome to ClusterJam")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 50)
                    
                    VStack(spacing: 15) {
                        TextField("Email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal, 30)
                    
                    Button(action: isCreatingAccount ? createAccount : signIn) {
                        Text(isCreatingAccount ? "Create Account" : "Sign In")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    if !isCreatingAccount {
                        Button(action: forgotPassword) {
                            Text("Forgot Password?")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        isCreatingAccount.toggle()
                        email = ""
                        password = ""
                    }) {
                        Text(isCreatingAccount ? "Already have an account? Sign In" : "Don't have an account? Create one")
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 20)
                    
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: handleSignInWithApple
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .padding(.horizontal, 30)
                    .padding(.top, 20)
                    
                    Button(action: {
                        isSkipped = true
                    }) {
                        Text("Skip for Now")
                            .foregroundColor(.blue)
                            .padding()
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                    }
                    .padding(.top, 20)
                }
                
                Spacer()
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    func signIn() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    func createAccount() {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                signIn()
            }
        }
    }
    
    func forgotPassword() {
        guard !email.isEmpty else {
            alertTitle = "Error"
            alertMessage = "Please enter your email address."
            showAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertTitle = "Password Reset Failed"
                alertMessage = error.localizedDescription
            } else {
                alertTitle = "Password Reset Email Sent"
                alertMessage = "Please check your email for instructions to reset your password."
            }
            showAlert = true
        }
    }
    
    func handleSignInWithApple(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                guard let token = appleIDCredential.identityToken else {
                    alertMessage = "Failed to fetch identity token"
                    showAlert = true
                    return
                }
                
                guard let tokenString = String(data: token, encoding: .utf8) else {
                    alertMessage = "Failed to encode token"
                    showAlert = true
                    return
                }
                
                let credential = OAuthProvider.credential(withProviderID: "apple.com", idToken: tokenString, rawNonce: nil)
                
                Auth.auth().signIn(with: credential) { (authResult, error) in
                    if let error = error {
                        alertMessage = error.localizedDescription
                        showAlert = true
                        return
                    }
                }
            }
        case .failure(let error):
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}


struct MainAppView: View {
    @StateObject private var playlistManager = PlaylistManager()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingSignInView = false
    @State private var showingSignInAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            BannerView()
                .frame(height: 60)
            TabView {
                if #available(iOS 16.0, *) {
                    
                    NavigationStack {
                        DiscoverView()
                    }
                    .tabItem {
                        Image(systemName: "star.fill")
                        Text("Discover")
                    }
                    
                    NavigationStack {
                        ArtistListView()
                    }
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Artists")
                    }
                    
                    NavigationStack {
                        PlaylistView()
                    }
                    .environmentObject(playlistManager)
                    .tabItem {
                        Image(systemName: "rectangle.stack.fill")
                        Text("Playlists")
                    }
                    
                    NavigationStack {
                        WizardView()
                    }
                    .tabItem {
                        Image(systemName: "waveform.path")
                        Text("Song Wizard")
                    }
                    
                    NavigationStack {
                        AccountView()
                    }
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Account")
                    }
                } else {
                    
                    NavigationView {
                        DiscoverView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Image(systemName: "star.fill")
                        Text("Discover")
                    }
                    
                    NavigationView {
                        ArtistListView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("Artists")
                    }
                    
                    NavigationView {
                        PlaylistView()
                    }
                    .environmentObject(playlistManager)
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Image(systemName: "rectangle.stack.fill")
                        Text("Playlists")
                    }
                    
                    NavigationView {
                        WizardView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Image(systemName: "waveform.path")
                        Text("Song Wizard")
                    }
                    
                    NavigationView {
                        AccountView()
                    }
                    .navigationViewStyle(StackNavigationViewStyle())
                    .tabItem {
                        Image(systemName: "person.circle")
                        Text("Account")
                    }
                }
            }
            
            .onChange(of: authManager.isSignedIn) { newValue in
                if newValue {
                    showingSignInView = false
                }
            }
        }
        .alert(isPresented: $showingSignInAlert) {
            Alert(
                title: Text("Sign In Required"),
                message: Text("You need to sign in to create and manage playlists."),
                primaryButton: .default(Text("Sign In"), action: {
                    showingSignInView = true
                }),
                secondaryButton: .cancel()
            )
        }
        .fullScreenCover(isPresented: $showingSignInView) {
            SignInView(isSkipped: .constant(false))
        }
        .onAppear {
            if !authManager.isSignedIn {
                showingSignInAlert = true
            }
        }
    }
}
