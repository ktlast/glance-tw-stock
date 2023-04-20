// struct Position {
//     symbol_code: String,
//     share: i32,
//     at_cost: u16
// }

use std::collections::HashMap;


// fn fetch_symbols() {
    // }
    
// fn main() {


fn main() -> Result<(), Box<dyn std::error::Error>> {
    let resp = reqwest::blocking::get("https://httpbin.org/ip")?
        .json::<HashMap<String, String>>()?;
    println!("{:#?}", resp);
    Ok(())
}




