# Package

version       = "0.1.0"
author        = "nbaertsch"
description   = "A new awesome nimble package"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["server"]
binDir        = "bin"


# Dependencies

requires "nim >= 2.0.0"
requires "mummy"
requires "mustache"
