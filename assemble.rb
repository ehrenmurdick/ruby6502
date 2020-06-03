OPCODE = /^\s*([a-z]+)\s*(#?)([%$]?)([[:xdigit:]]*)/

DIRECTIVE = /\s*\.([a-zA-Z0-9]+)/

RADICES = Hash.new('').merge({
  '$' => '0x',
  '%' => '0b',
})

MODES = {
  'im' => /#/,
}

def assemble_to_rasm(filename)
  lines = File.readlines(filename)
  lines.map do |line|
    tokenize(line.strip)
  end
end

class Line
  def to_rasm
    "LINE"
  end
end

class Directive < Line
  def initialize(expr)
    DIRECTIVE.match(expr)
    @name = $1
  end

  def to_rasm
    @name
  end
end

class Blank < Line
  def to_rasm
    ''
  end
end

class Opcode < Line
  attr_accessor :mnemonic, :mode, :radix

  def initialize(expr)
    OPCODE.match(expr)
    @mnemonic = $1
    @mode = parse_mode(expr)
    @radix = RADICES[$3]
    @value = $4
  end

  def parse_mode(expr)
    mode = MODES.find do |k, v|
      v =~ expr
    end

    if mode.nil?
      return "ab"
    else
      return mode[0]
    end
  end

  def value
    if @value
      @radix + @value
    end
  end

  def to_rasm
    %Q{#{@mnemonic}_#{@mode} #{value}}
  end
end

def tokenize(expr)
  case expr
  when OPCODE
    return Opcode.new(expr)
  when DIRECTIVE
    return Directive.new(expr)
  else
    return Blank.new
  end
end
