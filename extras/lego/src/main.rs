use dotenv::dotenv;
use reqwest::Error;
use serde::{Deserialize, Serialize};
use std::{env, fs::File, io::Write};
use tokio;

#[derive(Deserialize, Serialize, Debug)]
struct LegoSet {
    set_num: String,
    name: String,
    year: u16,
    theme_id: u16,
    num_parts: u32,
    set_img_url: Option<String>,
    set_url: Option<String>
}

#[derive(Deserialize, Debug)]
struct LegoSetsResponse {
    next: Option<String>,
    results: Vec<LegoSet>,
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    dotenv().ok();
    let api_key = env::var("API_KEY").expect("API_KEY must be set");
    let mut all_sets = Vec::new();
    let mut next_url = Some(format!(
        "https://rebrickable.com/api/v3/lego/sets/?page_size=1000&key={}", api_key
    ));

    while let Some(url) = next_url {
        println!("Fetching page...");
        let response = reqwest::get(&url).await?;
        let sets_response: LegoSetsResponse = response.json().await?;

        all_sets.extend(sets_response.results);
        next_url = sets_response.next;
        tokio::time::sleep(tokio::time::Duration::from_millis(30)).await;
    }

    println!("Total sets collected: {}", all_sets.len());

    let file_path = "lego_sets.json";
    let file = File::create(file_path);
    match file {
        Ok(mut file) => {
            let json_data = serde_json::to_string_pretty(&all_sets);
            match json_data {
                Ok(data) => {
                    if let Err(e) = write!(file, "{}", data) {
                        eprintln!("Failed to write to file: {} {}", file_path, e);
                    } else {
                        println!("Successfully wrote data to {}", file_path);
                    }
                }
                Err(e) => {
                    eprintln!("Failed to serialize LEGO sets: {}", e);
                }
            }
        }
        Err(e) => {
            eprintln!("Failed to create file: {}", e);
        }
    }
    Ok(())
}
