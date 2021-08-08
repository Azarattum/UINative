# UI Native
Jailbreak tweak to bring some native iOS APIs for web.

## Building:
This tweak is built with [orion](https://github.com/theos/orion) via [theos](https://github.com/theos/theos).

You need to have these environment variables set (change `<DEVICE IP>`):
```sh
#!/bin/sh

export THEOS=/opt/theos
export PATH=$THEOS/bin:$PATH
export THEOS_DEVICE_IP=<DEVICE IP>
export THEOS_DEVICE_PORT=22
```

Build and deploy the package to your phone:
```sh
make do
```