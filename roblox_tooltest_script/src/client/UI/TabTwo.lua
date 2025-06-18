local window = require(script.Parent.UI_Base):new()
function window:Awake(_obj)
    self:BindingClickEvent(self.Close_Text, function(...)
        self:HideUI()
    end)
    self:BindingClickEvent(self.OpenUITow_Text, function(...)
        self.UIMgr:ShowUI("NewUI")
    end)
end

function window:OnOpen()
end
function window:OnClose()
end

return window