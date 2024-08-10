import gleam/result
import pevensie/internal/auth.{type AuthConfig, AuthConfig}
import pevensie/internal/drivers.{
  type Connected, type Disabled, type Disconnected, connect_auth_driver,
  disconnect_auth_driver,
}

pub type Pevensie(user_metadata, auth_status) {
  Pevensie(auth_config: AuthConfig(user_metadata, auth_status))
}

pub fn new() -> Pevensie(user_metadata, Disabled) {
  Pevensie(auth.AuthDisabled)
}

pub fn with_auth(
  _pevensie: Pevensie(old_user_metadata, old_auth_status),
  auth auth_config: AuthConfig(user_metadata, auth_status),
) -> Pevensie(user_metadata, auth_status) {
  Pevensie(auth_config)
}

pub fn connect_auth(
  pevensie: Pevensie(user_metadata, Disconnected),
) -> Result(Pevensie(user_metadata, Connected), Nil) {
  let assert AuthConfig(driver, user_metadata_decoder) = pevensie.auth_config

  connect_auth_driver(driver)
  |> result.map(fn(driver) {
    Pevensie(AuthConfig(user_metadata_decoder:, driver:))
  })
}

pub fn disconnect_auth(
  pevensie: Pevensie(user_metadata, Connected),
) -> Result(Pevensie(user_metadata, Disconnected), Nil) {
  let assert AuthConfig(driver, user_metadata_decoder) = pevensie.auth_config

  disconnect_auth_driver(driver)
  |> result.map(fn(driver) {
    Pevensie(AuthConfig(user_metadata_decoder:, driver:))
  })
}
