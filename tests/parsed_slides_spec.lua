local parse = require("present")._parsed_slides

local eq = assert.are.same
describe("present.parsed_slides", function()
  it("Should parse an empty file", function()
    eq({
      slides = {
        {
          title = '',
          body = {},
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
        }
      }
    }, parse { '# hellow', 'world' })
  end)
end)
