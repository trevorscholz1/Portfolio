package main

import (
	"context"
	"encoding/json"
	"fmt"
	"html/template"
	"log"
	"math/rand/v2"
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

	templates, err = template.ParseFiles("index.html")
	if err != nil {
		log.Fatal(err)
	}

	http.HandleFunc("/", handleHome)
	http.HandleFunc("/random", handleRandomVideo)

	log.Println("Server starting on http://localhost:8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func handleHome(w http.ResponseWriter, r *http.Request) {
	data := VideoData{}
	templates.Execute(w, data)
}

func handleRandomVideo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Redirect(w, r, "/", http.StatusSeeOther)
		return
	}

	channelID := r.FormValue("channel_id")
	if channelID == "" {
		data := VideoData{Error: "Please enter a channel ID"}
		templates.Execute(w, data)
		return
	}

	videos, err := getAllVideos(youtubeService, channelID)
	if err != nil {
		data := VideoData{Error: "Error fetching videos: " + err.Error(), ChannelID: channelID}
		templates.Execute(w, data)
		return
	}

	if len(videos) == 0 {
		data := VideoData{Error: "No videos found for this channel", ChannelID: channelID}
		templates.Execute(w, data)
		return
	}

	index := rand.N(len(videos))
	video := videos[index]

	data := VideoData{
		Title:     video.Snippet.Title,
		VideoID:   video.Snippet.ResourceId.VideoId,
		ChannelID: channelID,
	}

	if err := templates.Execute(w, data); err != nil {
		http.Error(w, "Error rendering template: "+err.Error(), http.StatusInternalServerError)
		return
	}
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
