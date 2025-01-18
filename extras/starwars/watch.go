package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"math/rand"
	"net/http"
	"os"

	"google.golang.org/api/option"
	"google.golang.org/api/youtube/v3"
)

type Config struct {
	APIKey string `json:"api_key"`
}

type VideoData struct {
	Title     string
	VideoID   string
	Error     string
	ChannelID string
}

type SearchResult struct {
	ChannelTitle string
	ChannelID    string
}

var (
	youtubeService *youtube.Service
	config         *Config
	templates      *template.Template
)

func main() {
	var err error
	config, err = loadConfig("config.json")
	if err != nil {
		log.Fatal(err)
	}

	ctx := context.Background()
	youtubeService, err = youtube.NewService(ctx, option.WithAPIKey(config.APIKey))
	if err != nil {
		log.Fatal(err)
	}

	templates, err = template.ParseFiles("index.html", "results.html")
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/search", handleSearch)
	http.HandleFunc("/random", handleRandomVideo)

	log.Println("Server starting on http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	templates.ExecuteTemplate(w, "index.html", nil)
}

func handleSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	query := r.FormValue("query")
	if query == "" {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Please enter a search query"})
		return
	}

	results, err := searchChannels(youtubeService, query)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error searching for channels: " + err.Error()})
		return
	}

	templates.ExecuteTemplate(w, "results.html", results)
}

func handleRandomVideo(w http.ResponseWriter, r *http.Request) {
	channelID := r.URL.Query().Get("channel_id")
	if channelID == "" {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	videos, err := getAllVideos(youtubeService, channelID)
	if err != nil {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "Error fetching videos: " + err.Error()})
		return
	}

	if len(videos) == 0 {
		templates.ExecuteTemplate(w, "index.html", map[string]string{"Error": "No videos found for this channel"})
		return
	}

	// Select a random video
	index := rand.Intn(len(videos))
	video := videos[index]

	data := VideoData{
		Title:     video.Snippet.Title,
		VideoID:   video.Snippet.ResourceId.VideoId,
		ChannelID: channelID,
	}

	templates.ExecuteTemplate(w, "index.html", data)
}

func searchChannels(service *youtube.Service, query string) ([]SearchResult, error) {
	call := service.Search.List([]string{"snippet"}).Q(query).Type("channel").MaxResults(10)
	response, err := call.Do()
	if err != nil {
		return nil, err
	}

	var results []SearchResult
	for _, item := range response.Items {
		results = append(results, SearchResult{
			ChannelTitle: item.Snippet.ChannelTitle,
			ChannelID:    item.Snippet.ChannelId,
		})
	}

	return results, nil
}

func getAllVideos(service *youtube.Service, channelID string) ([]*youtube.PlaylistItem, error) {
	channelsResponse, err := service.Channels.List([]string{"contentDetails"}).Id(channelID).Do()
	if err != nil {
		return nil, err
	}
	if len(channelsResponse.Items) == 0 {
		return nil, fmt.Errorf("channel not found")
	}
	uploadsPlaylistID := channelsResponse.Items[0].ContentDetails.RelatedPlaylists.Uploads

	var videos []*youtube.PlaylistItem
	playlistItemsRequest := service.PlaylistItems.List([]string{"snippet"}).PlaylistId(uploadsPlaylistID)
	for {
		playlistItemsResponse, err := playlistItemsRequest.Do()
		if err != nil {
			return nil, err
		}
		videos = append(videos, playlistItemsResponse.Items...)
		if playlistItemsResponse.NextPageToken == "" {
			break
		}
		playlistItemsRequest = playlistItemsRequest.PageToken(playlistItemsResponse.NextPageToken)
	}
	return videos, nil
}

func loadConfig(filename string) (*Config, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	var config Config
	err = json.Unmarshal(data, &config)
	if err != nil {
		return nil, err
	}
	return &config, nil
}
