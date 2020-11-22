# Bidirectional Text: Left-to-right (Latin) and right-to-left (Arabic).
#
# See https://en.wikipedia.org/wiki/Bidirectional_text
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

  module_function

  # Wrap *str* in a pair of characters: Left-to-Right Embedding
  def ltr_embed(str)
    LRE + str + PDF
  end

  # Wrap *str* in a pair of characters: Right-to-Left Embedding
  def rtl_embed(str)
    RLE + str + PDF
  end

  # Wrap *str* in a pair of characters: Left-to-Right Override
  def ltr_override(str)
    LRO + str + PDF
  end

  # Wrap *str* in a pair of characters: Right-to-Left Override
  def rtl_override(str)
    RLO + str + PDF
  end

  # Wrap *str* in a pair of characters: Left-to-Right Isolate
  def ltr_isolate(str)
    LRI + str + PDI
  end

  # Wrap *str* in a pair of characters: Right-to-Left Isolate
  def rtl_isolate(str)
    RLI + str + PDI
  end

  # Wrap *str* in a pair of characters: First Strong Isolate
  def first_strong_isolate(str)
    FSI + str + PDI
  end

  BIDI_CONTROLS = LRE + RLE + PDF + LRO + RLO + LRI + RLI + FSI + PDI

  LRM = "\u{200E}".freeze
  RLM = "\u{200F}".freeze
  ALM = "\u{061C}".freeze

  LEFT_TO_RIGHT_MARK = LRM
  RIGHT_TO_LEFT_MARK = RLM
  ARABIC_LETTER_MARK = ALM

  # Add bidi formatting characters to *pname*
  # otherwise /dev/sda will be presented as dev/sda/ in RTL context
  # @param pname [Pathname]
  def pathname_bidi_to_s(pname)
    isolated_components = pname.each_filename.map { |fn| first_strong_isolate(fn) }

    isolated_components.unshift("") if pname.absolute?
    joined = isolated_components.join(File::SEPARATOR) # "/" pedantry

    ltr_isolate(joined)
  end

  # Return a copy of *str* where bidirectional formatting characters are removed
  # @param str [String]
  # @return [String]
  def bidi_strip(str)
    str.tr(BIDI_CONTROLS, "")
  end
end
