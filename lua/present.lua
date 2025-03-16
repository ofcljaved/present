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

local function create_floating_window(config, enter)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter or false, config)
  return { buf = buf, win = win }
end

---Default executor for lua code
---@param block present.Block
local execute_lua_code = function(block)
  local original_print = print

  local output = {}

  print = function(...)
    local args = { ... }
    local message = table.concat(vim.tbl_map(tostring, args), "\t")
    table.insert(output, message)
  end

  local chunk = loadstring(block.body)
  pcall(function()
    if not chunk then
      table.insert(output, " <<<BROKEN CODE>>>")
    else
      chunk()
    end
    return output
  end)

  print = original_print

  return output
end

M.create_system_executor = function(program)
  return function(block)
    local tempfile = vim.fn.tempname()
    vim.fn.writefile(vim.split(block.body, "\n"), tempfile)

    local result = vim.system({ program, tempfile }, { text = true }):wait()
    return vim.split(result.stdout, "\n")
  end
end

local options = {
  executors = {
    lua = execute_lua_code,
    javascript = M.create_system_executor "node"
  }
}

M.setup = function(opts)
  opts = opts or {}
  opts.executors = opts.executors or {}

  opts.executors.lua = opts.executors.lua or execute_lua_code
  opts.executors.javascript = opts.executors.javascript or M.create_system_executor "node"

  options = opts
end

---@class present.Slides
---@fields slides present.Slide[]: The slides of the file

---@class present.Slide
---@field title string: Title of the slide containing heading of markdown
---@field body string[]: Body of the slide containing rest of markdown
---@field blocks present.Block[]: The codeblock inside of a slide
---
---@class present.Block
---@field language string: The language of the codeblock
---@field body string: The body of the codeblock

---Take some lines and parses them
---@param lines string[]: The lines in the buffer
---@return present.Slides
local parsed_slides = function(lines)
  local slides = { slides = {} }
  local current_slide = {
    title = "",
    body = {},
    blocks = {}
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
        blocks = {}
      }
    else
      table.insert(current_slide.body, line)
    end
  end

  table.insert(slides.slides, current_slide)

  for _, slide in ipairs(slides.slides) do
    local block = {
      language = nil,
      body = ""
    }
    local inside_block = false
    for _, line in ipairs(slide.body) do
      if vim.startswith(line, "```") then
        if not inside_block then
          inside_block = true
          block.language = string.sub(line, 4)
        else
          inside_block = false
          block.body = vim.trim(block.body)
          table.insert(slide.blocks, block)
        end
      else
        if inside_block then
          block.body = block.body .. line .. "\n"
        end
      end
    end
  end
  return slides
end

local create_window_configuration = function()
  local width = vim.o.columns
  local height = vim.o.lines

  local header_height = 1 + 2                                    -- 1 + border
  local footer_height = 1                                        -- 1, no border
  local body_height = height - header_height - footer_height - 2 -- 2 is for bottom border
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
      height = body_height,
      style = "minimal",
      border = { " ", " ", " ", " ", " ", "", " ", " ", },
      col = 8,
      row = 3,
    },
    footer = {
      relative = "editor",
      width = width,
      height = footer_height,
      style = "minimal",
      border = { " ", "─", " ", "", "", "", "", "", },
      col = 0,
      row = height - 1,
      zindex = 2,
    },
  }
end

local state = {
  parsed = {},
  current_slide = 1,
  floats = {},
  title = ''
}

local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

local present_keymap = function(key, cb)
  vim.keymap.set("n", key, cb, {
    buffer = state.floats.body.buf
  })
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0

  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  state.parsed = parsed_slides(lines)
  state.current_slide = 1
  state.title = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

  local windows = create_window_configuration()

  state.floats.background = create_floating_window(windows.background)
  state.floats.header = create_floating_window(windows.header)
  state.floats.body = create_floating_window(windows.body, true)
  state.floats.footer = create_floating_window(windows.footer)

  foreach_float(function(_, float)
    vim.bo[float.buf].filetype = "markdown"
  end)

  -- IN ORDER TO SET COLOR OF THE FLOATING WINDOW
  local slide_bg = get_theme_bg()
  vim.api.nvim_set_hl(1, "NORMALFLOAT", { bg = slide_bg })
  foreach_float(function(_, float)
    vim.api.nvim_win_set_hl_ns(float.win, 1)
  end)

  local set_slide_content = function(idx)
    local width = vim.o.columns
    local slide = state.parsed.slides[idx]
    local padding = string.rep(" ", (width - #slide.title) / 2)
    local title = padding .. slide.title
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false, { title })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
    local footer = string.format(
      " %d / %d | %s",
      state.current_slide,
      #state.parsed.slides,
      state.title
    )
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })
  end
  present_keymap("n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end)

  present_keymap("p", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end)

  present_keymap("q", function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end)

  present_keymap("X", function()
    local slide = state.parsed.slides[state.current_slide]

    local block = slide.blocks[1]
    if not block then
      print("No block on this page")
      return
    end

    local executor = options.executors[block.language]
    if not executor then
      print("No valid executor for this language")
      return
    end

    -- Table  to capture print messages
    local output = { "# Code,", "", "```" .. block.language }
    vim.list_extend(output, vim.split(block.body, "\n"))
    table.insert(output, "```")

    table.insert(output, "")
    table.insert(output, "# Output")
    table.insert(output, "")
    table.insert(output, "```")
    vim.list_extend(output, executor(block))
    table.insert(output, "```")

    local buf = vim.api.nvim_create_buf(false, true)
    local temp_width = math.floor(vim.o.columns * 0.8)
    local temp_height = math.floor(vim.o.lines * 0.8)
    local output_win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      noautocmd = true,
      border = "double",
      width = temp_width,
      height = temp_height,
      row = math.floor((vim.o.lines - temp_height) / 2),
      col = math.floor((vim.o.columns - temp_width) / 2)
    })
    vim.bo[buf].filetype = "markdown"
    vim.api.nvim_win_set_hl_ns(output_win, 1)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
  end)

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
    buffer = state.floats.body.buf,
    callback = function()
      -- Reset it back to the original setting
      for option, config in pairs(restore) do
        vim.opt[option] = config.original
      end
      foreach_float(function(_, float)
        pcall(vim.api.nvim_win_close, float.win, true)
      end)
    end
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("present-resized", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win) or state.floats.body.win == nil then
        return
      end
      local updated = create_window_configuration()
      foreach_float(function(name, _)
        vim.api.nvim_win_set_config(state.floats[name].win, updated[name])
      end)
      foreach_float(function(_, float)
        vim.api.nvim_win_set_hl_ns(float.win, 1)
      end)
      -- Re-calculates  current slide content
      set_slide_content(state.current_slide)
    end
  })
  set_slide_content(state.current_slide)
end
-- vim.print(parsed_slides {
--   "#hello",
--   "This is first slide",
--   "##sub heading",
--   "#world",
--   "This is secomd slide"
-- })

-- M.start_presentation { bufnr = 39 }
M._parsed_slides = parsed_slides

return M
