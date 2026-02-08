--!strict
--[[
    ConfirmationDialog.lua
    Reusable modal confirmation dialog

    Features:
    - Semi-transparent backdrop
    - Centered dialog box
    - Title and description text
    - Confirm and Cancel buttons
    - Escape key to cancel
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

export type ConfirmationDialogObject = {
    frame: Frame,
    show: (self: ConfirmationDialogObject, title: string, description: string, onConfirm: () -> (), onCancel: (() -> ())?) -> (),
    hide: (self: ConfirmationDialogObject) -> (),
    destroy: (self: ConfirmationDialogObject) -> (),
    isVisible: (self: ConfirmationDialogObject) -> boolean,
}

local Theme = {
    Background = Color3.fromRGB(15, 15, 22),
    Surface = Color3.fromRGB(25, 25, 35),
    SurfaceLight = Color3.fromRGB(35, 35, 48),
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(140, 140, 155),
    Danger = Color3.fromRGB(255, 95, 95),
    Success = Color3.fromRGB(85, 220, 120),
    Radius = UDim.new(0, 10),
    Bold = Enum.Font.GothamBold,
    Medium = Enum.Font.GothamMedium,
    Regular = Enum.Font.Gotham,
    Fast = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    Normal = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local ConfirmationDialog = {}
ConfirmationDialog.__index = ConfirmationDialog

--[[
    Create a new confirmation dialog
    @param parent - The parent ScreenGui
    @return ConfirmationDialogObject
]]
function ConfirmationDialog.new(parent: ScreenGui): ConfirmationDialogObject
    local self = setmetatable({}, ConfirmationDialog)

    self._isVisible = false
    self._onConfirm = nil :: (() -> ())?
    self._onCancel = nil :: (() -> ())?
    self._escapeConnection = nil :: RBXScriptConnection?

    -- Backdrop (semi-transparent overlay)
    self.frame = Instance.new("Frame")
    self.frame.Name = "ConfirmationDialog"
    self.frame.Size = UDim2.new(1, 0, 1, 0)
    self.frame.Position = UDim2.new(0, 0, 0, 0)
    self.frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    self.frame.BackgroundTransparency = 1
    self.frame.Visible = false
    self.frame.ZIndex = 100
    self.frame.Parent = parent

    -- Click backdrop to cancel
    local backdropButton = Instance.new("TextButton")
    backdropButton.Name = "Backdrop"
    backdropButton.Size = UDim2.new(1, 0, 1, 0)
    backdropButton.BackgroundTransparency = 1
    backdropButton.Text = ""
    backdropButton.ZIndex = 100
    backdropButton.Parent = self.frame

    backdropButton.MouseButton1Click:Connect(function()
        self:_handleCancel()
    end)

    -- Dialog box
    local dialog = Instance.new("Frame")
    dialog.Name = "Dialog"
    dialog.Size = UDim2.new(0, 320, 0, 180)
    dialog.Position = UDim2.new(0.5, -160, 0.5, -90)
    dialog.BackgroundColor3 = Theme.Background
    dialog.ZIndex = 101
    dialog.Parent = self.frame
    self._dialog = dialog

    local dialogCorner = Instance.new("UICorner")
    dialogCorner.CornerRadius = Theme.Radius
    dialogCorner.Parent = dialog

    local dialogStroke = Instance.new("UIStroke")
    dialogStroke.Color = Theme.SurfaceLight
    dialogStroke.Thickness = 2
    dialogStroke.Parent = dialog

    -- Title
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -30, 0, 35)
    title.Position = UDim2.new(0, 15, 0, 15)
    title.BackgroundTransparency = 1
    title.Text = "Confirm"
    title.TextColor3 = Theme.Text
    title.TextSize = 22
    title.Font = Theme.Bold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.ZIndex = 102
    title.Parent = dialog
    self._title = title

    -- Description
    local description = Instance.new("TextLabel")
    description.Name = "Description"
    description.Size = UDim2.new(1, -30, 0, 50)
    description.Position = UDim2.new(0, 15, 0, 50)
    description.BackgroundTransparency = 1
    description.Text = "Are you sure?"
    description.TextColor3 = Theme.TextSecondary
    description.TextSize = 15
    description.Font = Theme.Regular
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.TextYAlignment = Enum.TextYAlignment.Top
    description.TextWrapped = true
    description.ZIndex = 102
    description.Parent = dialog
    self._description = description

    -- Button container
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "Buttons"
    buttonContainer.Size = UDim2.new(1, -30, 0, 45)
    buttonContainer.Position = UDim2.new(0, 15, 1, -60)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 102
    buttonContainer.Parent = dialog

    -- Cancel button
    local cancelButton = Instance.new("TextButton")
    cancelButton.Name = "Cancel"
    cancelButton.Size = UDim2.new(0.5, -5, 1, 0)
    cancelButton.Position = UDim2.new(0, 0, 0, 0)
    cancelButton.BackgroundColor3 = Theme.Surface
    cancelButton.Text = "Cancel"
    cancelButton.TextColor3 = Theme.Text
    cancelButton.TextSize = 16
    cancelButton.Font = Theme.Bold
    cancelButton.AutoButtonColor = true
    cancelButton.ZIndex = 103
    cancelButton.Parent = buttonContainer

    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancelButton

    local cancelStroke = Instance.new("UIStroke")
    cancelStroke.Color = Theme.SurfaceLight
    cancelStroke.Thickness = 1
    cancelStroke.Parent = cancelButton

    -- Cancel button hover
    cancelButton.MouseEnter:Connect(function()
        TweenService:Create(cancelButton, Theme.Fast, { BackgroundColor3 = Theme.SurfaceLight }):Play()
    end)
    cancelButton.MouseLeave:Connect(function()
        TweenService:Create(cancelButton, Theme.Fast, { BackgroundColor3 = Theme.Surface }):Play()
    end)

    cancelButton.MouseButton1Click:Connect(function()
        self:_handleCancel()
    end)

    -- Confirm button
    local confirmButton = Instance.new("TextButton")
    confirmButton.Name = "Confirm"
    confirmButton.Size = UDim2.new(0.5, -5, 1, 0)
    confirmButton.Position = UDim2.new(0.5, 5, 0, 0)
    confirmButton.BackgroundColor3 = Theme.Danger
    confirmButton.Text = "Confirm"
    confirmButton.TextColor3 = Theme.Text
    confirmButton.TextSize = 16
    confirmButton.Font = Theme.Bold
    confirmButton.AutoButtonColor = true
    confirmButton.ZIndex = 103
    confirmButton.Parent = buttonContainer

    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 8)
    confirmCorner.Parent = confirmButton

    -- Confirm button hover
    local confirmHoverColor = Color3.fromRGB(255, 120, 120)
    confirmButton.MouseEnter:Connect(function()
        TweenService:Create(confirmButton, Theme.Fast, { BackgroundColor3 = confirmHoverColor }):Play()
    end)
    confirmButton.MouseLeave:Connect(function()
        TweenService:Create(confirmButton, Theme.Fast, { BackgroundColor3 = Theme.Danger }):Play()
    end)

    confirmButton.MouseButton1Click:Connect(function()
        self:_handleConfirm()
    end)

    self._confirmButton = confirmButton
    self._cancelButton = cancelButton

    return self :: ConfirmationDialogObject
end

--[[
    Handle confirm action
]]
function ConfirmationDialog:_handleConfirm()
    if self._onConfirm then
        self._onConfirm()
    end
    self:hide()
end

--[[
    Handle cancel action
]]
function ConfirmationDialog:_handleCancel()
    if self._onCancel then
        self._onCancel()
    end
    self:hide()
end

--[[
    Show the dialog
    @param title - Dialog title
    @param description - Dialog description text
    @param onConfirm - Callback when confirmed
    @param onCancel - Optional callback when cancelled
]]
function ConfirmationDialog:show(title: string, description: string, onConfirm: () -> (), onCancel: (() -> ())?)
    self._title.Text = title
    self._description.Text = description
    self._onConfirm = onConfirm
    self._onCancel = onCancel

    self._isVisible = true
    self.frame.Visible = true
    self.frame.BackgroundTransparency = 1

    -- Animate in
    TweenService:Create(self.frame, Theme.Normal, { BackgroundTransparency = 0.5 }):Play()

    self._dialog.Position = UDim2.new(0.5, -160, 0.5, -70)
    TweenService:Create(self._dialog, Theme.Normal, {
        Position = UDim2.new(0.5, -160, 0.5, -90),
    }):Play()

    -- Listen for escape key
    if self._escapeConnection then
        self._escapeConnection:Disconnect()
    end
    self._escapeConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            self:_handleCancel()
        end
    end)
end

--[[
    Hide the dialog
]]
function ConfirmationDialog:hide()
    self._isVisible = false

    -- Disconnect escape listener
    if self._escapeConnection then
        self._escapeConnection:Disconnect()
        self._escapeConnection = nil
    end

    -- Animate out
    TweenService:Create(self.frame, Theme.Fast, { BackgroundTransparency = 1 }):Play()
    TweenService:Create(self._dialog, Theme.Fast, {
        Position = UDim2.new(0.5, -160, 0.5, -70),
    }):Play()

    task.delay(0.15, function()
        if not self._isVisible then
            self.frame.Visible = false
        end
    end)

    -- Clear callbacks
    self._onConfirm = nil
    self._onCancel = nil
end

--[[
    Check if dialog is visible
]]
function ConfirmationDialog:isVisible(): boolean
    return self._isVisible
end

--[[
    Destroy the component
]]
function ConfirmationDialog:destroy()
    if self._escapeConnection then
        self._escapeConnection:Disconnect()
    end
    self.frame:Destroy()
end

return ConfirmationDialog
