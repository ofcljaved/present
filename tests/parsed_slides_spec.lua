local parse = require("present")._parsed_slides

describe("present.parsed_slides", function()
  it("Should parse an empty file", function()
    assert.are.same({
      slides = {
        {
          title = '',
          body = {},
        }
      }
    }, parse {})
  end)
end)
