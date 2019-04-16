# Sunctl

An energy saving lighting controller for grow lights.

## Features

- Switches a relay when ambiant light level sits between two configurable values.
- Cloud interface based on node-red
- Time series light data saved on the cloud

## Usage

- Wire a circuit according to the fritzing schema (`.fzz` file)
- Import the node-red flow into your node-red instance
- Set up an MQTT server
- Copy the `.example` files, remove the extension and set values
- Flash the nodemcu firmware (`make flash`)
- Upload the lua scripts (`make upload`)
- [Configure the wifi](https://nodemcu.readthedocs.io/en/master/modules/enduser-setup/) on the device
