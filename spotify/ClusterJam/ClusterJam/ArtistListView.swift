import SwiftUI

struct ArtistListView: View {
    @EnvironmentObject var appData: AppData
    @State private var searchText: String = ""
    
    let darkBlue = Color(red: 4/255, green: 4/255, blue: 62/255)
    let lightBlue = Color(red: 151/255, green: 219/255, blue: 226/255)
    
    var body: some View {
        ZStack {
            darkBlue.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                SearchBar(text: $searchText, backgroundColor: darkBlue, textColor: lightBlue)
                    .padding()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(filteredArtists) { artist in
                            ArtistCard(artist: artist, lightBlue: lightBlue)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Artists")
                .toolbarBackground(darkBlue, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
    }
    
    var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return appData.artists
        } else {
            return appData.artists.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var backgroundColor: Color
    var textColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(textColor.opacity(0.7))
            
            TextField("Search artists", text: $text)
                .foregroundColor(.white)
                .accentColor(textColor)
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
        }
        .padding(12)
        .background(backgroundColor.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(textColor.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(15)
    }
}


struct ArtistCard: View {
    let artist: Artist
    let lightBlue: Color
    
    var body: some View {
        NavigationLink(destination: ClusterListView(artist: artist)) {
            VStack {
                AsyncImage(url: URL(string: artist.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(lightBlue, lineWidth: 2)
                        )
                } placeholder: {
                    ProgressView()
                        .frame(width: 120, height: 120)
                }
                
                Text(artist.name)
                    .font(.headline)
                    .foregroundColor(lightBlue)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 50)
                
                if artist.isDailyArtist {
                    Image(systemName: "star.fill")
                        .foregroundColor(lightBlue)
                        .padding(.top, 5)
                }
            }
            .frame(width: 150, height: 200)
            .background(Color.white.opacity(0.1))
            .cornerRadius(15)
        }
    }
}
