import argus
import birl
import gleam/bit_array
import gleam/crypto.{Sha256}
import gleam/dict
import gleam/dynamic.{type Decoder}
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pevensie/drivers.{
  type AuthDriver, type Connected, type Disconnected, AuthDriver,
}
import pevensie/internal/encoder.{type Encoder}
import pevensie/net.{type IpAddress}
import pevensie/session.{type Session}
import pevensie/user.{
  type User, type UserSearchFields, type UserUpdate, Set, UserInsert,
  UserSearchFields, UserUpdate, default_user_search_fields, default_user_update,
}

// ----- PevensieAuth ----- //

pub opaque type PevensieAuth(driver, user_metadata, connected) {
  PevensieAuth(
    driver: AuthDriver(driver, user_metadata),
    user_metadata_decoder: Decoder(user_metadata),
    user_metadata_encoder: Encoder(user_metadata),
    cookie_key: String,
  )
}

pub fn new(
  driver driver: AuthDriver(driver, user_metadata),
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
  user_metadata_encoder user_metadata_encoder: Encoder(user_metadata),
  cookie_key cookie_key: String,
) -> PevensieAuth(driver, user_metadata, Disconnected) {
  PevensieAuth(
    driver:,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  )
}

pub fn connect(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Disconnected),
) -> Result(PevensieAuth(auth_driver, user_metadata, Connected), Nil) {
  let PevensieAuth(
    driver: auth_driver,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  ) = pevensie_auth

  auth_driver.connect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieAuth(
      driver: AuthDriver(..auth_driver, driver: internal_driver),
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    )
  })
}

pub fn disconnect(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
) -> Result(PevensieAuth(auth_driver, user_metadata, Disconnected), Nil) {
  let PevensieAuth(
    driver: auth_driver,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  ) = pevensie_auth

  auth_driver.disconnect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieAuth(
      driver: AuthDriver(..auth_driver, driver: internal_driver),
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    )
  })
}

// ----- User CRUD Functions ----- //

pub fn list_users(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  filters: UserSearchFields,
) -> Result(List(User(user_metadata)), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  driver.list_users(driver.driver, filters, user_metadata_decoder)
}

pub fn get_user_by_id(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  id: String,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  use users <- result.try(driver.list_users(
    driver.driver,
    UserSearchFields(..default_user_search_fields(), id: Some([id])),
    user_metadata_decoder,
  ))

  case users {
    [user] -> Ok(user)
    _ -> Error(Nil)
  }
}

pub fn get_user_by_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email: String,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  use users <- result.try(driver.list_users(
    driver.driver,
    UserSearchFields(..default_user_search_fields(), email: Some([email])),
    user_metadata_decoder,
  ))

  case users {
    [user] -> Ok(user)
    _ -> Error(Nil)
  }
}

fn hash_password(password: String) {
  argus.hasher()
  |> argus.hash(password, argus.gen_salt())
}

pub fn get_user_by_email_and_password(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email: String,
  password: String,
) -> Result(User(user_metadata), Nil) {
  use user <- result.try(get_user_by_email(pevensie_auth, email))
  case argus.verify(user.password_hash |> option.unwrap(""), password) {
    Ok(True) -> Ok(user)
    _ -> Error(Nil)
  }
}

pub fn create_user_with_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email: String,
  password: String,
  user_metadata: user_metadata,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, user_metadata_encoder:, ..) =
    pevensie_auth

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
      app_metadata: user.new_app_metadata(dict.new()),
      user_metadata: user_metadata,
    ),
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

pub fn update_user(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  id: String,
  user_update: UserUpdate(user_metadata),
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, user_metadata_encoder:, ..) =
    pevensie_auth

  driver.update_user(
    driver.driver,
    "id",
    id,
    user_update,
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

pub fn set_user_role(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  id: String,
  role: Option(String),
) -> Result(User(user_metadata), Nil) {
  update_user(
    pevensie_auth,
    id,
    UserUpdate(..default_user_update(), role: Set(role)),
  )
}

pub fn set_user_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  id: String,
  email: String,
) -> Result(User(user_metadata), Nil) {
  update_user(
    pevensie_auth,
    id,
    UserUpdate(..default_user_update(), email: Set(email)),
  )
}

pub fn set_user_password(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  id: String,
  password: Option(String),
) -> Result(User(user_metadata), Nil) {
  let password_hash_result = case password {
    None -> Ok(None)
    Some(password) ->
      hash_password(password)
      |> result.replace_error(Nil)
      |> result.map(fn(hashes) { Some(hashes.encoded_hash) })
  }

  use password_hash <- result.try(password_hash_result)
  update_user(
    pevensie_auth,
    id,
    UserUpdate(..default_user_update(), password_hash: Set(password_hash)),
  )
}

// ----- Session CRUD Functions ----- //

pub fn create_session(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
  ttl_seconds: Option(Int),
) -> Result(Session, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

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
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session_id: String,
) -> Result(Option(Session), Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.get_session(driver.driver, session_id, None, None)
}

pub fn delete_session(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session_id: String,
) -> Result(Nil, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.delete_session(driver.driver, session_id)
}

// ----- User Authentication ----- //

pub fn log_in_user(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email: String,
  password: String,
  ip: Option(IpAddress),
  user_agent: Option(String),
) -> Result(#(Session, User(user_metadata)), Nil) {
  use user <- result.try(get_user_by_email_and_password(
    pevensie_auth,
    email,
    password,
  ))

  process.start(
    fn() {
      update_user(
        pevensie_auth,
        user.id,
        UserUpdate(..default_user_update(), last_sign_in: Set(Some(birl.now()))),
      )
    },
    False,
  )

  create_session(pevensie_auth, user.id, ip, user_agent, Some(24 * 60 * 60))
  |> result.map(fn(session) { #(session, user) })
}

// ----- Cookies ----- //

fn sha256_hash(data: String, key: String) -> Result(String, Nil) {
  let key = bit_array.from_string(key)
  let data = bit_array.from_string(data)
  Ok(crypto.sign_message(data, key, Sha256))
}

pub fn create_cookie(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session: Session,
) -> Result(String, Nil) {
  let PevensieAuth(cookie_key:, ..) = pevensie_auth
  io.println("Creating hash")
  use hash <- result.try(sha256_hash(session.id, cookie_key))
  io.println("Hash created")
  Ok(session.id <> "|" <> hash)
}

// TODO: Improve errors
pub fn verify_cookie(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  cookie: String,
) -> Result(String, Nil) {
  let PevensieAuth(cookie_key:, ..) = pevensie_auth
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
