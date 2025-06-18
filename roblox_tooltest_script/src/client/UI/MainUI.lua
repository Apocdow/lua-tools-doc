local MainUI = require(script.Parent.UI_Base):new()

function MainUI:Awake(_obj)
    -- 此时self即为ui对象
    self:BindingClickEvent(self.OpenTabOne_Text, function(...)
        self.UIMgr:ShowUI("TabOne")
    end)

    self:BindingClickEvent(self.OpenTabTwo_Text, function(...)
        self.UIMgr:ShowUI("TabTwo")
    end)

end

function MainUI:OnOpen()
end

function MainUI:OnClose()

end

return MainUI