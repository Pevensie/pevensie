import gleam/option.{type Option}
import gleam/result
import pevensie/drivers.{
  type CacheDriver, type Connected, type Disconnected, CacheDriver,
}

// ----- PevensieCache ----- //

pub type PevensieCache(driver, connected) {
  PevensieCache(driver: CacheDriver(driver))
}

pub fn new_cache_config(
  driver driver: CacheDriver(cache_driver),
) -> PevensieCache(cache_driver, Disconnected) {
  PevensieCache(driver:)
}

pub fn connect(
  pevensie_cache: PevensieCache(cache_driver, Disconnected),
) -> Result(PevensieCache(cache_driver, Connected), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.connect(driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieCache(driver: CacheDriver(..driver, driver: internal_driver))
  })
}

pub fn disconnect(
  pevensie_cache: PevensieCache(cache_driver, Connected),
) -> Result(PevensieCache(cache_driver, Disconnected), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.disconnect(driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieCache(driver: CacheDriver(..driver, driver: internal_driver))
  })
}

// ----- Cache CRUD Functions ----- //

pub fn set(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type: String,
  key: String,
  value: String,
  ttl_seconds: Option(Int),
) -> Result(Nil, Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.store(driver.driver, resource_type, key, value, ttl_seconds)
}

pub fn get(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type: String,
  key: String,
) -> Result(Option(String), Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.get(driver.driver, resource_type, key)
}

pub fn delete(
  pevensie_cache: PevensieCache(cache_driver, Connected),
  resource_type: String,
  key: String,
) -> Result(Nil, Nil) {
  let PevensieCache(driver) = pevensie_cache

  driver.delete(driver.driver, resource_type, key)
}
