# Package

version       = "0.1.0"
author        = "zhoupeng"
description   = "A proxy server"
license       = "MIT"
srcDir        = "src"
bin = @["proxy"]

# Dependencies

requires "nim >= 0.18.1"
requires "fnmatch"
requires "zip"

