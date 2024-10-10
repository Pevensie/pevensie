import gleam/bit_array
import gleam/crypto.{Sha256}
import gleam/json

pub type Encoder(a) =
  fn(a) -> json.Json

pub fn sha256_hash(data: String, key: String) -> Result(String, Nil) {
  let key = bit_array.from_string(key)
  let data = bit_array.from_string(data)
  Ok(crypto.sign_message(data, key, Sha256))
}
