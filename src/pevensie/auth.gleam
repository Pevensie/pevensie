import gleam/dynamic.{type Decoder}
import pevensie/drivers.{
  type AuthDriver, type Connected, type Disabled, type Disconnected,
}
import pevensie/internal/auth
import pevensie/internal/pevensie.{type Pevensie}
import pevensie/internal/user.{type User as InternalUser}

pub type User(user_metadata) =
  InternalUser(user_metadata)

pub type AuthConfig(driver, user_metadata, connected) =
  auth.AuthConfig(driver, user_metadata, connected)

pub fn new_auth_config(
  driver driver: AuthDriver(driver, user_metadata),
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
) -> AuthConfig(driver, user_metadata, Disconnected) {
  auth.AuthConfig(driver, user_metadata_decoder)
}

pub fn disabled() -> AuthConfig(Nil, user_metadata, Disabled) {
  auth.AuthDisabled
}

pub fn get_user_by_id(
  pevensie: Pevensie(user_metadata, auth_driver, Connected),
  id: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder) =
    pevensie.auth_config

  driver.get_user(driver.driver, "id", id, user_metadata_decoder)
}

pub fn get_user_by_email(
  pevensie: Pevensie(user_metadata, auth_driver, Connected),
  email: String,
) -> Result(User(user_metadata), Nil) {
  let assert auth.AuthConfig(driver, user_metadata_decoder) =
    pevensie.auth_config

  driver.get_user(driver.driver, "email", email, user_metadata_decoder)
}
