use reqwest::blocking::{Client, Response};
use std::collections::HashMap;
use std::error::Error;
use std::io::{self, Write};
use std::thread;
use std::time::Duration;
use std::time::Instant;

fn main() -> Result<(), Box<dyn Error>> {
    // Set up initial adjustable params
    let base_url = "https://jsonplaceholder.typicode.com";
    let endpoint = "/posts";
    let mut params = HashMap::new();
    params.insert(String::from("userId"), String::from("1"));

    // Set up rate limit
    let rate_limit = Duration::from_secs(1);
    let last_request_time = Instant::now() - rate_limit;

    loop {
        // Read user-provided argument from stdin
        print!("Enter command (append, update, delete, or q to quit): ");
        io::stdout().flush()?;
        let mut command = String::new();
        io::stdin().read_line(&mut command)?;
        let command = command.trim();

        match command {
            "append" => {
                // Read user-provided argument from stdin
                print!("Enter new parameter key: ");
                io::stdout().flush()?;
                let mut key = String::new();
                io::stdin().read_line(&mut key)?;
                let key = key.trim().to_string();

                print!("Enter new parameter value: ");
                io::stdout().flush()?;
                let mut value = String::new();
                io::stdin().read_line(&mut value)?;
                let value = value.trim().to_string();

                // Append new parameter to adjustable params
                params.insert(key.to_string(), value.to_string());
            },
            "update" => {
                // Read user-provided argument from stdin
                print!("Enter parameter key to update: ");
                io::stdout().flush()?;
                let mut key = String::new();
                io::stdin().read_line(&mut key)?;
                let key = key.trim().to_string();

                print!("Enter new parameter value: ");
                io::stdout().flush()?;
                let mut value = String::new();
                io::stdin().read_line(&mut value)?;
                let value = value.trim().to_string();

                // Update existing parameter in adjustable params
                if let Some(v) = params.get_mut(&key) {
                    *v = value;
                } else {
                    println!("Key not found");
                }
            },
            "delete" => {
                // Read user-provided argument from stdin
                print!("Enter parameter key to delete: ");
                io::stdout().flush()?;
                let mut key = String::new();
                io::stdin().read_line(&mut key)?;
                let key = key.trim().to_string();

                // Remove parameter from adjustable params
                params.remove(&key);
            },
            "q" => {
                break;
            },
            _ => {
                println!("Invalid command");
                continue;
            }
        }

        // Calculate elapsed time since last request
        let elapsed_time = Instant::now() - last_request_time;
        if elapsed_time < rate_limit {
            // Wait for the remaining time before next request
            thread::sleep(rate_limit - elapsed_time);
        }

        // Create a reqwest Client
        let client = Client::new();

        // Build the request with adjustable params
        let request = client
            .get(&format!("{}{}", base_url, endpoint))
            .query(&params)
            .build()?;

        // Send the request and get the response
        let response: Response = client.execute(request)?;

        // Get the response body as text
        let body = response.text()?;

        // Print the response body
        println!("{}", body);

        // Wait for fixed interval before next request
        thread::sleep(Duration::from_secs(1));
    }

    Ok(())
}
