import argus
import gleam/bit_array
import gleam/crypto.{Sha256}
import gleam/dict
import gleam/dynamic.{type Decoder}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pevensie/drivers.{
  type AuthDriver, type Connected, type Disabled, type Disconnected,
}
import pevensie/internal/auth
import pevensie/internal/encoder.{type Encoder}
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/session.{type Session}
import pevensie/internal/user.{
  type User as InternalUser, type UserInsert as UserInsertInternal,
  type UserUpdate as UserUpdateInternal, Set, UserInsert, UserUpdate,
  default_user_update,
}
import pevensie/net.{type IpAddress}

pub type User(user_metadata) =
  InternalUser(user_metadata)

pub type UserInsert(user_metadata) =
  UserInsertInternal(user_metadata)

pub type UserUpdate(user_metadata) =
  UserUpdateInternal(user_metadata)

pub type AuthConfig(driver, user_metadata, connected) =
  auth.AuthConfig(driver, user_metadata, connected)

pub fn new_auth_config(
  driver driver: AuthDriver(driver, user_metadata),
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
  user_metadata_encoder user_metadata_encoder: Encoder(user_metadata),
  cookie_key cookie_key: String,
) -> AuthConfig(driver, user_metadata, Disconnected) {
  auth.AuthConfig(
    driver:,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  )
}

pub fn disabled() -> AuthConfig(Nil, user_metadata, Disabled) {
  auth.AuthDisabled
}

pub fn get_user_by_id(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  id: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder, ..) =
    pevensie.auth_config

  driver.get_user(driver.driver, "id", id, user_metadata_decoder)
}

pub fn get_user_by_email(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  email: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder, ..) =
    pevensie.auth_config

  driver.get_user(driver.driver, "email", email, user_metadata_decoder)
}

fn hash_password(password: String) {
  argus.hasher()
  |> argus.hash(password, argus.gen_salt())
}

pub fn get_user_by_email_and_password(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  email: String,
  password: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder, ..) =
    pevensie.auth_config

  use user <- result.try(driver.get_user(
    driver.driver,
    "email",
    email,
    user_metadata_decoder,
  ))
  case argus.verify(user.password_hash |> option.unwrap(""), password) {
    Ok(True) -> Ok(user)
    _ -> Error(Nil)
  }
}

pub fn create_user_with_email(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  email: String,
  password: String,
  user_metadata: user_metadata,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(
    driver:,
    user_metadata_decoder:,
    user_metadata_encoder:,
    ..,
  ) = pevensie.auth_config

  // TODO: Handle errors
  let assert Ok(hashed_password) = hash_password(password)

  driver.insert_user(
    driver.driver,
    UserInsert(
      role: None,
      email: email,
      password_hash: Some(hashed_password.encoded_hash),
      email_confirmed_at: None,
      phone_number: None,
      phone_number_confirmed_at: None,
      last_sign_in: None,
      app_metadata: dict.new(),
      user_metadata: user_metadata,
    ),
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

pub fn set_user_role(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  id: String,
  role: Option(String),
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(
    driver:,
    user_metadata_decoder:,
    user_metadata_encoder:,
    ..,
  ) = pevensie.auth_config

  driver.update_user(
    driver.driver,
    "id",
    id,
    UserUpdate(..default_user_update(), role: Set(role)),
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

pub fn create_session(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  user_id: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
  ttl_seconds: Option(Int),
) -> Result(Session, Nil) {
  let assert auth.AuthConfig(driver, ..) = pevensie.auth_config

  driver.create_session(
    driver.driver,
    user_id,
    ip,
    user_agent,
    ttl_seconds,
    False,
  )
}

pub fn get_session(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  session_id: String,
) -> Result(Option(Session), Nil) {
  let assert auth.AuthConfig(driver, ..) = pevensie.auth_config

  driver.get_session(driver.driver, session_id, None, None)
}

pub fn delete_session(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    Connected,
  ),
  session_id: String,
) -> Result(Nil, Nil) {
  let assert auth.AuthConfig(driver, ..) = pevensie.auth_config

  driver.delete_session(driver.driver, session_id)
}

pub fn log_in_user(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    Connected,
  ),
  email: String,
  password: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
) -> Result(#(Session, User(user_metadata)), Nil) {
  use user <- result.try(get_user_by_email_and_password(
    pevensie,
    email,
    password,
  ))
  create_session(pevensie, user.id, ip, user_agent, Some(24 * 60 * 60))
  |> result.map(fn(session) { #(session, user) })
}

fn sha256_hash(data: String, key: String) -> Result(String, Nil) {
  let key = bit_array.from_string(key)
  let data = bit_array.from_string(data)
  Ok(crypto.sign_message(data, key, Sha256))
}

pub fn create_cookie(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  session: Session,
) -> Result(String, Nil) {
  let assert auth.AuthConfig(cookie_key:, ..) = pevensie.auth_config
  io.println("Creating hash")
  use hash <- result.try(sha256_hash(session.id, cookie_key))
  io.println("Hash created")
  Ok(session.id <> "|" <> hash)
}

// TODO: Improve errors
pub fn verify_cookie(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
  cookie: String,
) -> Result(String, Nil) {
  let assert auth.AuthConfig(cookie_key:, ..) = pevensie.auth_config
  let cookie_parts = string.split(cookie, "|")
  case cookie_parts {
    [session_id, hash_string] -> {
      use new_hash <- result.try(sha256_hash(session_id, cookie_key))
      case new_hash == hash_string {
        True -> Ok(session_id)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
