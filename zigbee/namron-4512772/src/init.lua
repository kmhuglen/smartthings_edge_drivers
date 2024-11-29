local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local device_management = require "st.zigbee.device_management"
local clusters = require "st.zigbee.zcl.clusters"

local comp = {
  "buttonGroup1On",
  "buttonGroup1Off",
  "buttonGroup2On",
  "buttonGroup2Off",
  "buttonGroup3On",
  "buttonGroup3Off",
  "buttonGroup4On",
  "buttonGroup4Off"
}

local button_map = {
  ["01_01"] = 1,
  ["01_00"] = 2,
  ["02_01"] = 3,
  ["02_00"] = 4,
  ["03_01"] = 5,
  ["03_00"] = 6,
  ["04_01"] = 7,
  ["04_00"] = 8
}

-- Define the button_handler to handle Zigbee messages for button presses
local button_handler = function(driver, device, zb_rx)
  -- DEBUG Log the full Zigbee message for debugging
  --device.log.debug("Full Zigbee message: " .. tostring(zb_rx))

  -- Convert the Zigbee message to a string
  local zb_rx_str = tostring(zb_rx)

  -- Regular expression to extract src_endpoint and ZCLCommandId
  local src_endpoint = zb_rx_str:match("src_endpoint: 0x(%x+)")
  local zcl_command_id = zb_rx_str:match("ZCLCommandId: 0x(%x+)")

  local key = src_endpoint .. "_" .. zcl_command_id
  local button_index = button_map[key]

  -- DEBUG Log the extracted values
  --device.log.debug("src_endpoint (ButtonGroup number): " .. (src_endpoint or "not found"))
  --device.log.debug("ZCLCommandId (01 = On, 00 = Off): " .. (zcl_command_id or "not found"))

  if button_index then
    local pushed_ev = capabilities.button.button.pushed()
    pushed_ev.state_change = true
    device.profile.components[comp[button_index]]:emit_event(pushed_ev)
  else
    device.log.warn("Unmapped button press detected.")
  end
end

-- Function called when the device is added
local device_added = function(driver, device)
  local num_button = 8 -- Assuming device has 8 buttons
  for i = 1, num_button, 1 do
      local component_id = comp[i]
      if device.profile.components[component_id] then
          -- device.log.debug("Initializing button " .. i .. " (" .. component_id .. ")")
          device.profile.components[component_id]:emit_event(capabilities.button.supportedButtonValues({"pushed"})) -- Assuming button only support pushed
      else
          device.log.warn("Component " .. component_id .. " does not exist in the device profile")
      end
  end
end

-- Configuration function for the device
local do_configure = function(self, device)
    device:configure()
    device:send(clusters.PowerConfiguration.attributes.BatteryPercentageRemaining:read(device))
end

-- Define the driver with capabilities, zigbee handlers, and lifecycle handlers
local namron_driver = {
  supported_capabilities = {
    capabilities.battery,
  },
  zigbee_handlers = {
    cluster = {
        [clusters.OnOff.ID] = {
            [clusters.OnOff.commands.On.ID] = button_handler,
            [clusters.OnOff.commands.Off.ID] = button_handler
        }
    },
  },
  lifecycle_handlers = {
      added = device_added,
      doConfigure = do_configure
  }
}

-- Register the driver for default handlers
defaults.register_for_default_handlers(namron_driver, namron_driver.supported_capabilities)

-- Run the Zigbee driver
local zigbee_driver = ZigbeeDriver("namron_driver", namron_driver)
zigbee_driver:run()