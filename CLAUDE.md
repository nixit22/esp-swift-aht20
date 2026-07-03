# SwiftAHT20

Swift driver for the AHT20 temperature/humidity sensor. Swift module name: **`AHT20`**.

Depends on: `SwiftPlatform`, `SwiftI2C`, `SwiftSupport`

## Files

| File | Role |
|---|---|
| `src/AHT20.swift` | Public `AHT20` struct — sensor driver |

## Public API

```swift
let bus = I2CMasterBus(i2cPort: I2C_NUM_0, sdaIoNum: GPIO_NUM_6, sclIoNum: GPIO_NUM_7)
let sensor = AHT20(i2cMasterBus: bus)
try sensor.setup()
let (temperature, humidity) = try sensor.read()
// No explicit cleanup — deinit handles it.
// Declare bus before sensor so Swift destroys them in reverse order (sensor first) — required IDF order.
```

## Non-obvious patterns

**Pure-Swift component** — no C wrapper, no `module.modulemap`. The driver only calls into the `I2C` and `Platform` Swift modules, so no Clang module bridge is needed.

**Caller owns the bus** — `AHT20.init(i2cMasterBus:)` registers a `Device` on the caller-supplied `I2CMasterBus` but does not own the bus. `AHT20` is `~Copyable`; its `deinit` removes only the device (via the wrapped `Device`'s own `deinit`) — the bus is cleaned up separately by the caller's `I2CMasterBus` going out of scope.

**I2C address fixed at 0x38** — AHT20 has a non-configurable 7-bit address.
