pub type Connected

pub type Disconnected

pub type Disabled

pub type ConnectError(driver_error) {
  ConnectDriverError(driver_error)
  AlreadyConnected
}

pub type DisconnectError(driver_error) {
  DisconnectDriverError(driver_error)
  NotConnected
}

/// A function that connects the driver. This may
/// set up any connections or perform any other setup
/// required to make the driver ready to use.
pub type ConnectFunction(driver, driver_error) =
  fn(driver) -> Result(driver, ConnectError(driver_error))

/// A function that disconnects the driver. This may
/// tear down any connections or perform any other cleanup
/// required once the driver is no longer needed.
pub type DisconnectFunction(driver, driver_error) =
  fn(driver) -> Result(driver, DisconnectError(driver_error))
