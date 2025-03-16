local parse = require("present")._parsed_slides

local eq = assert.are.same
describe("present.parsed_slides", function()
  it("Should parse an empty file", function()
    eq({
      slides = {
        {
          title = '',
          body = {},
          blocks = {},
        }
      }
    }, parse {})
  end)
  it("Should parse a file with one slide", function()
    eq({
      slides = {
        {
          title = '# hellow',
          body = {
            "world",
          },
          blocks = {}
        }
      }
    }, parse { '# hellow', 'world' })
  end)
  it("Should parse a file with one slide and one block", function()
    local results = parse {
      "# This is the title",
      " This is body",
      "```lua",
      "print('hi')",
      "```"
    }

    -- Should only have one slide
    eq(1, #results.slides)

    local slide = results.slides[1]
    eq('# This is the title', slide.title)

    eq({
      " This is body",
      "```lua",
      "print('hi')",
      "```"
    }, slide.body)

    eq({
      language = "lua",
      body = "print('hi')"
    }, slide.blocks[1])
  end)
end)
