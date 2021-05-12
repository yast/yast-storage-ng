# Copyright (c) [2020-2021] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

# Bidirectional Text: Left-to-right (Latin) and right-to-left (Arabic).
#
# See https://en.wikipedia.org/wiki/Bidirectional_text
#
# If you feel lost, try wrapping a piece of text that belongs together with
# {.first_strong_isolate First Strong Isolate}.
#
# Quoting from the standard, Unicode TR 9, Section 6.3 Formatting,
# where UPPER CASE simulates a RTL script:
#
# > The most common problematic case is that of neutrals on the
# > boundary of an embedded language. This can be addressed by
# > setting the level of the embedded text correctly. For example,
# > with all the text at level 0 the following occurs:
# >
# >     Memory:  he said "I NEED WATER!", and expired.
# >     Display: he said "RETAW DEEN I!", and expired.
# >
# > If the exclamation mark is to be part of the Arabic quotation,
# > then the user can select the text I NEED WATER! and explicitly
# > mark it as embedded Arabic, which produces the following result:
# >
# >     Memory:  he said "(RLI)I NEED WATER!(PDI)", and expired.
# >     Display: he said "!RETAW DEEN I", and expired.
module BidiMarkup
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

  # Wrap *str* in a pair of characters: Left-to-Right Embedding.
  #
  # @deprecated Use {.ltr_isolate}.
  #   Embedding is an older method that may have side effect on
  #   the *surrounding* text so since Unicode 6.3 (2013) it is discouraged
  #   in favor of Isolates.
  def ltr_embed(str)
    LRE + str + PDF
  end

  # Wrap *str* in a pair of characters: Right-to-Left Embedding.
  #
  # @deprecated Use {.rtl_isolate}.
  #   Embedding is an older method that may have side effect on
  #   the *surrounding* text so since Unicode 6.3 (2013) it is discouraged
  #   in favor of Isolates.
  def rtl_embed(str)
    RLE + str + PDF
  end

  # Wrap *str* in a pair of characters: Left-to-Right Override.
  #
  # Force text direction regardless of the characters it contains.
  # "Can be used to force a part number made of mixed English, digits
  # and Hebrew letters to be written from right to left."
  def ltr_override(str)
    LRO + str + PDF
  end

  # Wrap *str* in a pair of characters: Right-to-Left Override.
  #
  # Force text direction regardless of the characters it contains.
  # "Can be used to force a part number made of mixed English, digits
  # and Hebrew letters to be written from right to left."
  def rtl_override(str)
    RLO + str + PDF
  end

  # Wrap *str* in a pair of characters: Left-to-Right Isolate.
  def ltr_isolate(str)
    LRI + str + PDI
  end

  # Wrap *str* in a pair of characters: Right-to-Left Isolate.
  def rtl_isolate(str)
    RLI + str + PDI
  end

  # Wrap *str* in a pair of characters: First Strong Isolate.
  #
  # This is like LTR Isolate or RTL Isolate but the direction is decided by
  # the first character that is directionally strong (usually a letter, not
  # punctuation).
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
    return ltr_isolate(File::SEPARATOR) if pname.root?

    isolated_components = pname.each_filename.map { |fn| first_strong_isolate(fn) }

    isolated_components.unshift("") if pname.absolute?
    joined = isolated_components.join(File::SEPARATOR) # "/" pedantry

    ltr_isolate(joined)
  end

  # Return a copy of *str* where bidirectional formatting chars are removed.
  #
  # LRM, RLM, ALM are kept because they are not added by the methods
  # of this module, a human has probably added them instead.
  # @param str [String]
  # @return [String]
  def bidi_strip(str)
    str.tr(BIDI_CONTROLS, "")
  end
end
