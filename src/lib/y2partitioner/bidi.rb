# Bidirectional Text: Left-to-right (Latin) and right-to-left (Arabic).
module Bidi
  LRE = "\u{202A}".freeze
  RLE = "\u{202B}".freeze
  PDF = "\u{202C}".freeze
  LRO = "\u{202D}".freeze
  RLO = "\u{202E}".freeze
  LRI = "\u{2066}".freeze
  RLI = "\u{2067}".freeze
  FSI = "\u{2068}".freeze
  PDI = "\u{2069}".freeze

  LEFT_TO_RIGHT_EMBEDDING = LRE
  RIGHT_TO_LEFT_EMBEDDING = RLE
  POP_DIRECTIONAL_FORMATTING = PDF
  LEFT_TO_RIGHT_OVERRIDE = LRO
  RIGHT_TO_LEFT_OVERRIDE = RLO
  LEFT_TO_RIGHT_ISOLATE = LRI
  RIGHT_TO_LEFT_ISOLATE = RLI
  FIRST_STRONG_ISOLATE = FSI
  POP_DIRECTIONAL_ISOLATE = PDI

  BIDI_CONTROLS = LRE + RLE + PDF + LRO + RLO + LRI + RLI + FSI + PDI

  LRM = "\u{200E}".freeze
  RLM = "\u{200F}".freeze
  ALM = "\u{061C}".freeze

  LEFT_TO_RIGHT_MARK = LRM
  RIGHT_TO_LEFT_MARK = RLM
  ARABIC_LETTER_MARK = ALM

  # Add bidi formatting characters to *pn*
  # otherwise /dev/sda will be presented as dev/sda/ in RTL context
  # @param pn [Pathname]
  def pathname_bidi_to_s(pn)
    isolated_components = pn.each_filename.map do |fn|
      Bidi::FIRST_STRONG_ISOLATE + fn + Bidi::POP_DIRECTIONAL_ISOLATE
    end

    isolated_components.unshift("") if pn.absolute?
    joined = isolated_components.join(File::SEPARATOR) # "/" pedantry

    Bidi::LEFT_TO_RIGHT_ISOLATE + joined + POP_DIRECTIONAL_ISOLATE
  end
  module_function :pathname_bidi_to_s

  # Return a copy of *str* where bidirectional formatting characters are removed
  # @param str [String]
  # @return [String]
  def bidi_strip(str)
    str.tr(BIDI_CONTROLS, "")
  end
  module_function :bidi_strip
end
