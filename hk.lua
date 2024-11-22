local hk = {}

---@class Key
---@field keyid string
Key = {}
Key.__index = Key

---@param keyid string
---@return Key
function Key.new(keyid)
    local self = setmetatable({}, Key)
    self.keyid = keyid
    return self
end

---@param self Key
---@return string
function Key.__tostring(self)
    return "<" .. self.keyid .. ">"
end

---@class Key
SUPER = Key.new("super")
---@class Key
SHIFT = Key.new("shift")

---@class Key
A = Key.new("A")
---@class Key
H = Key.new("H")
---@class Key
J = Key.new("J")
---@class Key
K = Key.new("K")
---@class Key
L = Key.new("L")

---@class Binding
---@field modifiers Key[]
---@field key Key
---@field command string[]
local Binding = {}
Binding.__index = Binding

---@param modifiers Key[]
---@param key Key
---@param command string[]
function Binding.new(modifiers, key, command)
    local self = setmetatable({}, Binding)
    self.modifiers = modifiers
    self.key = key
    self.command = command
    return self
end

---@param separator string
---@param list any[]
---@return string
local function join(separator, list)
    local result = ""
    for i, item in ipairs(list) do
        if i > 1 then
            result = result .. separator
        end
        result = result .. tostring(item)
    end
    return result
end

---@param separator string
---@param left string
---@param right string
---@param list any[]
---@return string
local function joinSurround(separator, left, right, list)
    local result = ""
    for i, item in ipairs(list) do
        if i > 1 then
            result = result .. separator
        end
        result = result .. left .. tostring(item) .. right
    end
    return result
end

---@param self Binding
---@return string
function Binding.__tostring(self)
    return "[ "
        .. join(" + ", self.modifiers)
        .. " ] + "
        .. tostring(self.key)
        .. " => [ "
        .. joinSurround(", ", "<", ">", self.command)
        .. " ]"
end

---@type Binding[]
local bindings = {}

---@alias DynamicCommand (string | string[])[]

---@param dynamic_command DynamicCommand
---@param index integer
---@return string[]
local function populateDynamicCommand(dynamic_command, index)
    local static_command = {}
    for _, candidate in ipairs(dynamic_command) do
        local arg = candidate
        if type(candidate) == "table" then
            arg = candidate[index]
        end
        table.insert(static_command, arg)
    end
    return static_command
end

---@param dynamic_command DynamicCommand
---@return string[]?
local function unwrapStaticCommand(dynamic_command)
    for _, item in ipairs(dynamic_command) do
        if type(item) == "table" then
            return nil
        end
    end
    return dynamic_command
end

---@param dynamic_command DynamicCommand
---@return number?
local function dynamicCommandCardinality(dynamic_command)
    local cardinality = nil
    for _, candidate in ipairs(dynamic_command) do
        if type(candidate) == "table" then
            local new_cardinality = #candidate
            -- Mismatched cardinalities for any 2 dynamic arguments
            if cardinality ~= nil and cardinality ~= new_cardinality then
                return nil
            end
            cardinality = new_cardinality
        end
    end
    -- Allow dynamic command to function like static command, if no dynamic arguments are provided
    return cardinality or 1
end

---@param message any
---@return nil
local function eprint(message)
    io.stderr:write("Error: ")
    io.stderr:write(message)
    io.stderr:write("\n")
end

---@param modifiers Key[]
---@param key Key
---@param command string[]
---@return nil
local function addBinding(modifiers, key, command)
    local binding = Binding.new(modifiers, key, command)
    table.insert(bindings, binding)
end

---@param modifiers Key[]
---@param key Key
---@param command DynamicCommand
---@return boolean
local function addStaticBinding(modifiers, key, command)
    local static_command = unwrapStaticCommand(command)
    if static_command == nil then
        eprint("Cannot use dynamic command argument with single key argument")
        return false
    end
    addBinding(modifiers, key, static_command)
    return true
end

---@param modifiers Key[]
---@param keys Key[]
---@param command DynamicCommand
---@return boolean
local function addDynamicBinding(modifiers, keys, command)
    local cardinality = dynamicCommandCardinality(command)
    if cardinality == nil then
        eprint("Command contains multiple dynamic arguments with mismatched number of candidates")
        return false
    end
    if cardinality ~= #keys then
        eprint("Command contains dynamic argument of with incorrect number of candidates")
        return false
    end

    for i, key in ipairs(keys) do
        local static_command = populateDynamicCommand(command, i)
        addBinding(modifiers, key, static_command)
    end
    return true
end

---@param modifiers Key[]
---@param keys Key | Key[]
---@param command DynamicCommand[]
---@return boolean
function hk.bind(modifiers, keys, command)
    if getmetatable(keys) == Key then
        return addStaticBinding(modifiers, keys, command)
    else
        return addDynamicBinding(modifiers, keys, command)
    end
end

function hk.done()
    for _, binding in ipairs(bindings) do
        print(binding)
    end
end

return hk
