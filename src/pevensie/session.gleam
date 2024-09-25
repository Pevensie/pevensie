import birl.{type Time}
import gleam/option.{type Option}
import pevensie/net.{type IpAddress}

// ---- Session ----- //

pub type Session {
  Session(
    id: String,
    created_at: Time,
    expires_at: Option(Time),
    user_id: String,
    ip: Option(IpAddress),
    user_agent: Option(String),
  )
}
