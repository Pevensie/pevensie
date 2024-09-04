import gleam/dynamic.{type Decoder}
import pevensie/drivers.{type AuthDriver}
import pevensie/internal/encoder.{type Encoder}

pub type AuthConfig(driver, user_metadata, connected) {
  AuthConfig(
    driver: AuthDriver(driver, user_metadata),
    user_metadata_decoder: Decoder(user_metadata),
    user_metadata_encoder: Encoder(user_metadata),
  )
  AuthDisabled
}
