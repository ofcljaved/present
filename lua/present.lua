local M = {}

local function get_theme_bg()
  local function get_bg(hl_name)
    local bg = vim.api.nvim_get_hl(0, { name = hl_name }).bg
    return bg
  end
  local bg = get_bg("NormalFloat") or get_bg("Normal")
  if bg then return bg end

  local fallbacks = { "Pmenu", "VertSplit", "StatusLine", "TabLine" }
  for _, hl_name in ipairs(fallbacks) do
    bg = get_bg(hl_name)
    if bg then return bg end
  end

  return 0x1e1e1e
end

local function create_floating_window(config)
  -- Create a buffer
  local buf = vim.api.nvim_create_buf(false, true)

  -- Create a  floating window
  local win = vim.api.nvim_open_win(buf, true, config)

  return { buf = buf, win = win }
end

M.setup = function()
end

---@class present.Slides
---@fields slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: Title of the slide containing heading of markdown
---@field body string[]: Body of the slide containing rest of markdown

---Take some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parsed_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {}
  }

  local separator = "^#[^#]"

  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end

      current_slide = {
        title = line,
        body = {},
      }
    else
      table.insert(current_slide.body, line)
    end
  end

  table.insert(slides.slides, current_slide)

  return slides
end

local create_window_configuration = function()
  local width = vim.o.columns
  local height = vim.o.lines

  return {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = "minimal",
      col = 0,
      row = 0,
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      col = 0,
      row = 0,
      zindex = 2,
    },
    body = {
      relative = "editor",
      width = width - 8,
      height = height - 4,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", "", " ", " ", },
      col = 8,
      row = 3,
    },
    --footer = {}
  }
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parsed_slides(lines)
  local km = vim.keymap
  local current_slide = 1

  local windows = create_window_configuration()

  local background_float = create_floating_window(windows.background)
  local header_float = create_floating_window(windows.header)
  local body_float = create_floating_window(windows.body)

  vim.bo[header_float.buf].filetype = "markdown"
  vim.bo[body_float.buf].filetype = "markdown"

  -- IN ORDER TO SET COLOR OF THE FLOATING WINDOW
  local slide_bg = get_theme_bg()
  vim.api.nvim_set_hl(1, "NORMALFLOAT", { bg = slide_bg })
  vim.api.nvim_win_set_hl_ns(background_float.win, 1)
  vim.api.nvim_win_set_hl_ns(header_float.win, 1)
  vim.api.nvim_win_set_hl_ns(body_float.win, 1)

  local set_slide_content = function(idx)
    local slide = parsed.slides[idx]
    local padding = string.rep(" ", (width - #slide.title) / 2)
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(header_float.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(body_float.buf, 0, -1, false, slide.body)
  end
  km.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    set_slide_content(current_slide)
  end, {
    buffer = body_float.buf
  })

  km.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    set_slide_content(current_slide)
  end, {
    buffer = body_float.buf
  })

  km.set("n", "q", function()
    vim.api.nvim_win_close(body_float.win, true)
  end, {
    buffer = body_float.buf
  })

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0
    }
  }

  -- Set The options when we present slides
  for option, config in pairs(restore) do
    vim.opt[option] = config.present
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = body_float.buf,
    callback = function()
      -- Reset it back to the original setting
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end
      pcall(vim.api.nvim_win_close, header_float.win, true)
      pcall(vim.api.nvim_win_close, background_float.win, true)
    end
  })

  set_slide_content(current_slide)
end
-- vim.print(parsed_slides {
--   "#hello",
--   "This is first slide",
--   "##sub heading",
--   "#world",
--   "This is secomd slide"
-- })

M.start_presentation { bufnr = 36 }
return M
