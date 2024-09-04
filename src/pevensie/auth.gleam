import argus
import birl.{type Time}
import birl/duration
import gleam/dict
import gleam/dynamic.{type Decoder}
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import pevensie/cache
import pevensie/drivers.{
  type AuthDriver, type Connected, type Disabled, type Disconnected,
}
import pevensie/internal/auth
import pevensie/internal/encoder.{type Encoder}
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/user.{
  type User as InternalUser, type UserInsert as UserInsertInternal,
  type UserUpdate as UserUpdateInternal, Set, UserInsert, UserUpdate,
  default_user_update,
}
import youid/uuid

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
) -> AuthConfig(driver, user_metadata, Disconnected) {
  auth.AuthConfig(driver, user_metadata_decoder, user_metadata_encoder)
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
    driver,
    user_metadata_decoder,
    user_metadata_encoder,
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

pub type Session {
  Session(id: String, user_id: String, created_at: Time, expires_at: Time)
}

fn encode_session(session: Session) -> json.Json {
  json.object([
    #("id", json.string(session.id)),
    #("user_id", json.string(session.user_id)),
    #("created_at", json.string(birl.to_iso8601(session.created_at))),
    #("expires_at", json.string(birl.to_iso8601(session.expires_at))),
  ])
}

fn session_decoder() -> Decoder(Session) {
  let time_decoder = fn(time) {
    use time <- result.try(dynamic.string(time))
    birl.parse(time)
    |> result.replace_error([])
  }

  dynamic.decode4(
    Session,
    dynamic.field("id", dynamic.string),
    dynamic.field("user_id", dynamic.string),
    dynamic.field("created_at", time_decoder),
    dynamic.field("expires_at", time_decoder),
  )
}

const session_resource_type = "pevensie:session"

pub fn create_session(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    Connected,
  ),
  user_id: String,
  ttl_seconds: Option(Int),
) -> Result(Session, Nil) {
  // Check if the user exists
  use user <- result.try(get_user_by_id(pevensie, user_id))

  let ttl_seconds = option.unwrap(ttl_seconds, 24 * 60 * 60)
  let now = birl.now()
  let session =
    Session(
      id: uuid.v7_string(),
      user_id: user.id,
      created_at: now,
      expires_at: birl.add(now, duration.seconds(ttl_seconds)),
    )

  use _ <- result.try(cache.store(
    pevensie,
    session_resource_type,
    session.id,
    session
      |> encode_session
      |> json.to_string,
    Some(ttl_seconds),
  ))

  Ok(session)
}

pub fn get_session(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    Connected,
  ),
  session_id: String,
) -> Result(Option(Session), Nil) {
  use session <- result.try(cache.get(
    pevensie,
    session_resource_type,
    session_id,
  ))
  case session {
    None -> Ok(None)
    Some(session_string) -> {
      use decoded_session <- result.try(
        json.decode(session_string, session_decoder())
        |> result.replace_error(Nil),
      )
      Ok(Some(decoded_session))
    }
  }
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
  use _ <- result.try(cache.delete(pevensie, session_resource_type, session_id))
  Ok(Nil)
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
) -> Result(#(Session, User(user_metadata)), Nil) {
  use user <- result.try(get_user_by_email_and_password(
    pevensie,
    email,
    password,
  ))
  create_session(pevensie, user.id, Some(24 * 60 * 60))
  |> result.map(fn(session) { #(session, user) })
}
