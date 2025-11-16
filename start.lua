app.set_title("VoxelCore DevTools")
app.load_content()

local debugging_client = require "dev:debugging_client"
debugging_client.init(app)

local ui_util = require "dev:ui_util"
ui_util.init(app)

gui.load_document("dev:layouts/main.xml", "dev:main")
gui.root.root:add("<iframe id='main_frame' src='dev:projects' size-func='unpack(gui.get_viewport())'/>")
