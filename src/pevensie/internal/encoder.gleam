import gleam/json

pub type Encoder(a) =
  fn(a) -> json.Json
