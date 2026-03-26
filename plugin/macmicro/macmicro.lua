VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local os = import("os")
local filepath = import("path/filepath")

local cmdFile = ""

function init()
    local home = os.Getenv("HOME")
    local appSupport = filepath.Join(home, "Library", "Application Support", "MacMicro")
    cmdFile = filepath.Join(appSupport, "commands.pipe")

    micro.Log("macmicro: init, starting watcher")

    local watchCmd = string.format(
        'while true; do if [ -f "%s" ]; then cat "%s"; rm -f "%s"; fi; sleep 0.15; done',
        cmdFile, cmdFile, cmdFile
    )

    shell.JobStart(watchCmd, onOutput, onOutput, onExit)
end

function onOutput(out)
    for line in out:gmatch("[^\r\n]+") do
        local ok, err = pcall(processCommand, line)
        if not ok then
            micro.Log("macmicro: error: " .. tostring(err))
        end
    end
end

function onExit(str)
    micro.Log("macmicro: watcher exited: " .. tostring(str))
end

function processCommand(line)
    local cmd, args = line:match("^(%S+)%s*(.*)")
    if not cmd then return end

    local bp = micro.CurPane()
    if not bp then return end

    -- File operations
    if cmd == "open" then
        local path = args:match("^%s*(.-)%s*$")
        if path ~= "" then
            bp:HandleCommand("tab " .. path)
        end
    elseif cmd == "set" then
        bp:HandleCommand("set " .. args)
    elseif cmd == "help" then
        local topic = args:match("^%s*(.-)%s*$")
        bp:HandleCommand("help " .. topic)

    -- Tab navigation
    elseif cmd == "nexttab" then
        local tabs = micro.Tabs()
        local cur = tabs:Active()
        if cur < #tabs.List - 1 then tabs:SetActive(cur + 1) else tabs:SetActive(0) end
    elseif cmd == "prevtab" then
        local tabs = micro.Tabs()
        local cur = tabs:Active()
        if cur > 0 then tabs:SetActive(cur - 1) else tabs:SetActive(#tabs.List - 1) end
    elseif cmd == "tabswitch" then
        local n = tonumber(args)
        if n then
            local tabs = micro.Tabs()
            if n - 1 >= 0 and n - 1 < #tabs.List then tabs:SetActive(n - 1) end
        end

    -- Editor actions (called directly on BufPane, keybinding-independent)
    elseif cmd == "action" then
        local action = args:match("^%s*(.-)%s*$")
        if action == "Save" then bp:Save()
        elseif action == "Undo" then bp:Undo()
        elseif action == "Redo" then bp:Redo()
        elseif action == "Cut" then bp:Cut()
        elseif action == "CutLine" then bp:CutLine()
        elseif action == "Copy" then bp:Copy()
        elseif action == "CopyLine" then bp:CopyLine()
        elseif action == "Paste" then bp:Paste()
        elseif action == "SelectAll" then bp:SelectAll()
        elseif action == "Find" then bp:Find()
        elseif action == "FindNext" then bp:FindNext()
        elseif action == "FindPrevious" then bp:FindPrevious()
        elseif action == "DuplicateLine" then bp:DuplicateLine()
        elseif action == "Duplicate" then bp:Duplicate()
        elseif action == "CommandMode" then bp:CommandMode()
        elseif action == "Quit" then bp:Quit()
        elseif action == "QuitAll" then bp:QuitAll()
        elseif action == "AddTab" then bp:AddTab()
        elseif action == "NextTab" then bp:NextTab()
        elseif action == "PreviousTab" then bp:PreviousTab()
        elseif action == "ToggleHelp" then bp:ToggleHelp()
        else
            micro.Log("macmicro: unknown action: " .. action)
        end

    elseif cmd == "quit" then
        bp:Quit()
    end
end
