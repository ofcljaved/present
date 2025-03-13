local M = {}

local function create_floating_window(opts)
  opts = opts or {}

  -- Viewport width and height
  local vw = vim.o.columns;
  local vh = vim.o.lines;

  -- Window width and height
  local width = opts.width or math.floor(vw * 0.9)
  local height = opts.height or math.floor(vh * 0.9)

  -- Calculate the position to center the window
  local col = math.floor((vw - width) / 2)
  local row = math.floor((vh - height) / 2)

  -- Create a buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Window configuration
  ---@type vim.api.keyset.win_config
  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
  }

  -- Create a  floating window
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

M.setup = function()
end

---@class present.Slides
---@fields slides string[]: The slides of the file

---Take some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parsed_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {}

  local separator = "^#[^#]"

  for _, line in ipairs(lines) do
    -- print(line, "find:", line:find(separator), "|")
    if line:find(separator) then
      if #current_slide > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {}
    end
    table.insert(current_slide, line)
  end
  table.insert(slides.slides, current_slide)
  return slides
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parsed_slides(lines)
  local float = create_floating_window()
  local km = vim.keymap
  local current_slide = 1

  km.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, {
    buffer = float.buf
  })

  km.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[current_slide])
  end, {
    buffer = float.buf
  })

  km.set("n", "q", function()
    vim.api.nvim_win_close(float.win, true)
  end, {
    buffer = float.buf
  })

  vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[1])
end
-- vim.print(parsed_slides {
--   "#hello",
--   "This is first slide",
--   "##sub heading",
--   "#world",
--   "This is secomd slide"
-- })

-- M.start_presentation { bufnr = 11 }
return M
