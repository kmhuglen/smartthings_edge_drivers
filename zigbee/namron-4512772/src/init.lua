local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local device_management = require "st.zigbee.device_management"
local clusters = require "st.zigbee.zcl.clusters"
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"

local comp = {"button1", "button2", "button3", "button4", "button5", "button6", "button7", "button8"}

-- Define the button_handler to handle Zigbee messages for button presses
local button_handler = function(driver, device, zb_rx)
  -- Log the full Zigbee message for debugging
  device.log.debug("Full Zigbee message: " .. tostring(zb_rx))

  -- Convert the Zigbee message to a string
  local zb_rx_str = tostring(zb_rx)

  -- Regular expression to extract src_endpoint and ZCLCommandId
  local src_endpoint = zb_rx_str:match("src_endpoint: 0x(%x+)")
  local zcl_command_id = zb_rx_str:match("ZCLCommandId: 0x(%x+)")

  -- Log the extracted values
  device.log.debug("Extracted src_endpoint: " .. (src_endpoint or "not found"))
  device.log.debug("Extracted ZCLCommandId: " .. (zcl_command_id or "not found"))

  local pushed_ev = capabilities.button.button.pushed()
  pushed_ev.state_change = true

  if src_endpoint == "01" and zcl_command_id == "01" then
    device.log.debug("Button1 pressed")
    device.profile.components[comp[1]]:emit_event(pushed_ev)
  elseif src_endpoint == "01" and zcl_command_id == "00" then
    device.log.debug("Button2 pressed")
    device.profile.components[comp[2]]:emit_event(pushed_ev)
  elseif src_endpoint == "02" and zcl_command_id == "01" then
    device.log.debug("Button3 pressed")
    device.profile.components[comp[3]]:emit_event(pushed_ev)
  elseif src_endpoint == "02" and zcl_command_id == "00" then
    device.log.debug("Button4 pressed")
    device.profile.components[comp[4]]:emit_event(pushed_ev)
  elseif src_endpoint == "03" and zcl_command_id == "01" then
    device.log.debug("Button5 pressed")
    device.profile.components[comp[5]]:emit_event(pushed_ev)
  elseif src_endpoint == "03" and zcl_command_id == "00" then
    device.log.debug("Button6 pressed")
    device.profile.components[comp[6]]:emit_event(pushed_ev)
  elseif src_endpoint == "04" and zcl_command_id == "01" then
    device.log.debug("Button7 pressed")
    device.profile.components[comp[7]]:emit_event(pushed_ev)
  elseif src_endpoint == "04" and zcl_command_id == "00" then
    device.log.debug("Button8 pressed")
    device.profile.components[comp[8]]:emit_event(pushed_ev)
  else
    device.log.debug("Different button press detected.")
  end
end

-- Function called when the device is added
local device_added = function(driver, device)
    device:emit_event(capabilities.button.supportedButtonValues({"pushed", "held"}))
    device:emit_event(capabilities.button.button.pushed())
    local n_button = 8 -- Assuming device has 8 buttons
    for i = 1, n_button, 1 do
        device.profile.components[comp[i]]:emit_event(capabilities.button.supportedButtonValues({"pushed", "held"}))
        device.profile.components[comp[i]]:emit_event(capabilities.button.button.pushed())
    end
end

-- Configuration function for the device
local do_configure = function(self, device)
    device:configure()
    device:send(device_management.build_bind_request(device, 0xFC00, device.driver.environment_info.hub_zigbee_eui))
    device:send(clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
end

-- Define the driver with capabilities, zigbee handlers, and lifecycle handlers
local namron_driver = {
  supported_capabilities = {
      capabilities.button,
      capabilities.battery,
  },
  zigbee_handlers = {
      cluster = {
          [0xFC00] = {
              [0x00] = button_handler
          },
          [clusters.OnOff.ID] = {
              [clusters.OnOff.commands.On.ID] = button_handler,
              [clusters.OnOff.commands.Off.ID] = button_handler
          }
      },
  },
  lifecycle_handlers = {
      added = device_added,
      infoChanged = device_info_changed,
      doConfigure = do_configure
  }
}

-- Register the driver for default handlers
defaults.register_for_default_handlers(namron_driver, namron_driver.supported_capabilities)

-- Run the Zigbee driver
local zigbee_driver = ZigbeeDriver("namron-kanalbryter", namron_driver)
zigbee_driver:run()