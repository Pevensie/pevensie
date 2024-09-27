//// The session module contains types and functions for working with
//// Pevensie sessions.

import birl.{type Time}
import gleam/option.{type Option}
import pevensie/net.{type IpAddress}

// ---- Session ----- //

/// A Pevensie session. Sessions are used to identify users and
/// provide a way to track their activity.
///
/// Fields:
/// - `id`: The session's ID (unique).
/// - `created_at`: The time the session was created.
/// - `expires_at`: The time the session will expire.
/// - `user_id`: The ID of the user associated with the session.
/// - `ip`: The IP address of the user associated with the session.
/// - `user_agent`: The user agent of the user associated with the session.
///
/// When searching for sessions, auth drivers will check for IP and user
/// agent matches if the `ip` and `user_agent` fields are not `None`.
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
