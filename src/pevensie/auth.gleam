import argus
import gleam/dict
import gleam/dynamic.{type Decoder}
import gleam/option.{None, Some}
import gleam/result
import pevensie/drivers.{
  type AuthDriver, type Connected, type Disabled, type Disconnected,
  type Encoder,
}
import pevensie/internal/auth
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/user.{
  type User as InternalUser, type UserInsert as UserInsertInternal, UserInsert,
}

pub type User(user_metadata) =
  InternalUser(user_metadata)

pub type UserInsert(user_metadata) =
  UserInsertInternal(user_metadata)

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

pub fn verify_email_and_password(
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
