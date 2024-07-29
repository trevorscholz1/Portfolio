use reqwest::Error;
use serde::Deserialize;
use rand::seq::SliceRandom;
use tokio;
use dotenv::dotenv;
use std::env;

#[derive(Deserialize, Debug)]
struct LegoSet {
    set_num: String,
    name: String,
    year: u16,
    theme_id: u16,
    num_parts: u32,
    set_img_url: Option<String>,
}

#[derive(Deserialize, Debug)]
struct LegoSetsResponse {
    results: Vec<LegoSet>,
}

#[tokio::main]
async fn main() -> Result<(), Error> {
    dotenv().ok();

    let api_key = env::var("API_KEY").expect("API_KEY must be set");
    let url = format!("https://rebrickable.com/api/v3/lego/sets/?page_size=100&key={}", api_key);

    let response = reqwest::get(&url).await?;
    let sets_response: LegoSetsResponse = response.json().await?;

    if let Some(random_set) = sets_response.results.choose(&mut rand::thread_rng()) {
        println!("Random LEGO Set:");
        println!("Set Number: {}", random_set.set_num);
        println!("Name: {}", random_set.name);
        println!("Year: {}", random_set.year);
        println!("Theme ID: {}", random_set.theme_id);
        println!("Number of Parts: {}", random_set.num_parts);
        if let Some(img_url) = &random_set.set_img_url {
            println!("Image URL: {}", img_url);
        }
    } else {
        println!("No LEGO sets found.");
    }

    Ok(())
}
