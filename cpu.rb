class Program
  attr_accessor :ac, :labels, :src, :filename

  def self.load filename
    prog = new
    prog.instance_eval(File.read(filename), filename)
    prog.filename = filename
    prog
  end

  ADDR_MODES = {
    "ac" => ->(cpu, addr) { 'a' },
    "ip" => ->(cpu, addr) { nil },
    "im" => ->(cpu, addr) { nil },
    "ab" => ->(cpu, addr) { addr },
    "z"  => ->(cpu, addr) { addr },
    "zx" => ->(cpu, addr) { addr + cpu.x },
    "zy" => ->(cpu, addr) { addr + cpu.y },
    "ax" => ->(cpu, addr) { addr + cpu.x},
    "ay" => ->(cpu, addr) { addr + cpu.y },
    "iz" => ->(cpu, addr) {
      low = cpu.memory[addr]
      high = cpu.memory[addr + 1] * 0x100
      low + high
    },
    "ix" => ->(cpu, addr) {
      low = cpu.memory[addr + cpu.x]
      high = cpu.memory[addr + 1 + cpu.x] * 0x100
      low + high
    },
    "iax" => ->(cpu, addr) {
      low = cpu.memory[addr + cpu.x]
      high = cpu.memory[addr + 1 + cpu.x] * 0x100
      low + high
    },
    "iy" => ->(cpu, addr) {
      low = cpu.memory[addr]
      high = cpu.memory[addr + 1] * 0x100
      low + high + cpu.y
    },
    "ia" => ->(cpu, addr) {
      low = cpu.memory[addr]
      high = cpu.memory[addr + 1] * 0x100
      low + high
    },
  }

  def self.opcode name, modes, &block
    modes.each do |mode|
      if mode == "ip"
        method_name = name
      else
        method_name = [name, mode].compact.join('_')
      end
      define_method(method_name.to_sym) do |*args|
        addr = args[0]
        outerBlock = lambda do |prog|
          line = lambda do |cpu|
            cpu.pc += 1
            value = nil
            final_addr = ADDR_MODES[mode].call(cpu, addr)
            if !final_addr.nil?
              value = cpu[final_addr]
            else
              value = addr
            end
            block.call(cpu, self, final_addr, value)
          end
          line.define_singleton_method :asm do
            %Q{#{method_name} #{addr ? addr.to_s(16) : addr}}
          end
          prog.src.append(line)
          prog.ac += 1
        end
        outerBlock.call(self)
      end
    end
  end

  def inspect
    "<#{@filename}>"
  end

  def initialize
    @ac = 0
    @labels = {}
    @src = []
  end

  def label name
    labels[name] = ac
  end

  opcode :adc, %w{ im z zx ab ax ay ix iy iz } do |cpu, _, addr, val|
    cpu.flags.update 'nvzc', (cpu.a + val)
    cpu.a += val
  end

  opcode :jmp, %w{ ab } do |cpu, prog, _, label|
    cpu.pc = prog.labels[label]
  end

  opcode :ina, %w{ im } do |cpu, prog, _, _|
    cpu.a += 1
  end
  opcode :inx, %w{ im } do |cpu, prog, _, _|
    cpu.x += 1
  end

  opcode :brk, %w{ ip } do |cpu, _, _, _|
    cpu.running = false
  end

  opcode :lda, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    cpu.a = val
    cpu.flags.update 'nz', val
  end

  opcode :ldx, %w{ im z zy ab ay } do |cpu, prog, addr, val|
    cpu.x = val
    cpu.flags.update 'nz', val
  end

  opcode :ldy, %w{ im z zy ab ay } do |cpu, prog, addr, val|
    cpu.y = val
    cpu.flags.update 'nz', val
  end

  opcode :sta, %w{ z ax ab ax ay ix iy  iz } do |cpu, prog, addr, val|
    cpu[addr] = cpu.a
  end

  opcode :stx, %w{ z zy ab } do |cpu, prog, addr, val|
    cpu[addr] = cpu.x
  end

  opcode :sty, %w{ z zy ab } do |cpu, prog, addr, val|
    cpu[addr] = cpu.y
  end

  opcode :stz, %w{ z zx ab ax } do |cpu, prog, addr, val|
    cpu[addr] = 0
  end

  opcode :tax, %w{ ip } do |cpu, _, _, val|
    cpu.x = cpu.a
    cpu.flags.update 'nz', val
  end

  opcode :asl, %w{ ac z ax ab ax } do |cpu, prog, addr, val|
    cpu.flags.c = !(val & 0b1000_0000).zero?
    val = val << 1
    cpu.flags.update 'nz', val
    cpu[addr] = val
  end

  opcode :lsr, %w{ ac z zx ab ax } do |cpu, prog, addr, val|
    cpu.flags.c = !(val & 1).zero?
    val = val >> 1
    cpu.flags.update 'nz', cpu.a
    cpu[addr] = val
  end

  opcode :rol, %w{ ac z zx ab ax } do |cpu, prog, addr, val|
    carry = cpu.flags.c ? 1 : 0
    cpu.flags.c = !(val & 0b1000_0000).zero?
    val = carry + (val << 1)
    cpu.flags.update 'nz', val
    cpu[addr] = val
  end

  opcode :ror, %w{ ac z zx ab ax } do |cpu, prog, addr, val|
    carry = cpu.flags.c ? 128 : 0
    cpu.flags.c = !(val & 1).zero?
    val = carry + (val >> 1)
    cpu.flags.update 'nz', val
    cpu[addr] = val
  end

  opcode :and, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    val = val & cpu.a
    cpu.flags.update 'nz', val
    cpu.a = val
  end

  opcode :ora, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    val = val | cpu.a
    cpu.flags.update 'nz', val
    cpu.a = val
  end

  opcode :eor, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    val = val ^ cpu.a
    cpu.flags.update 'nz', val
    cpu.a = val
  end

  opcode :bit, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    val = val & cpu.a
    cpu.flags.update 'nzv', val
  end

  opcode :cmp, %w{ im z zx ab ax ay ix iy iz } do |cpu, prog, addr, val|
    cpu.flags.n = false
    if cpu.a > val
      cpu.flags.c, cpu.flags.z = true, false
    elsif cpu.a < val
      cpu.flags.n = true
      cpu.flags.c, cpu.flags.z = false, false
    else
      cpu.flags.c, cpu.flags.z = true, true
    end
  end

  opcode :cpx, %w{ im z ab } do |cpu, prog, addr, val|
    cpu.flags.n = false
    if cpu.x > val
      cpu.flags.c, cpu.flags.z = true, false
    elsif cpu.x < val
      cpu.flags.n = true
      cpu.flags.c, cpu.flags.z = false, false
    else
      cpu.flags.c, cpu.flags.z = true, true
    end
  end

  opcode :cpy, %w{ im z ab } do |cpu, prog, addr, val|
    cpu.flags.n = false
    if cpu.y > val
      cpu.flags.c, cpu.flags.z = true, false
    elsif cpu.y < val
      cpu.flags.n = true
      cpu.flags.c, cpu.flags.z = false, false
    else
      cpu.flags.c, cpu.flags.z = true, true
    end
  end

  # LDA #$A6
  # STA $00
  # LDA #$33
  # TRB $00
  opcode :trb, %w{ z ab } do |cpu, prog, addr, val|
    cpu.flags.z = (val & cpu.a).zero?
    a = cpu.a
    cpu.a = cpu.a ^ 0xff
    cpu.a = cpu.a & val
    cpu[addr] = cpu.a
    cpu.a = a
  end


  %w{ c d i v }.each do |f|
    opcode :"cl#{f}", %w{ ip } do |cpu, _, _, _|
      cpu.flags.send(:"#{f}=", false)
    end
    opcode :"se#{f}", %w{ ip } do |cpu, _, _, _|
      cpu.flags.send(:"#{f}=", true)
    end
  end
end

class Memory < Hash
  def []=(key, value)
    super(key, value % 256)
  end
end

class CPU
  attr_accessor :pc, :program, :running, :memory, :flags

  def self.register *names
    names.each do |name|
      define_method(name) do
        read_register(name)
      end

      define_method(:"#{name}=") do |v|
        write_register(name, v)
      end
    end
  end
  register :a, :x, :y

  def read_register named
    instance_variable_get("@#{named}")
  end

  def write_register named, value
    instance_variable_set("@#{named}", value.to_i % 256)
  end

  def [](index)
    case index
    when Numeric
      return memory[index]
    when String
      return read_register(index)
    end
  end

  def []=(index, value)
    case index
    when Numeric
      return memory[index] = value
    when String
      return write_register(index, value)
    end
  end

  def initialize(program)
    @pc = 0
    @program = program
    @running = true
    @memory = Memory.new(0)
    @a = 0
    @x = 0
    @y = 0
    @flags = Flags.new
  end

  class Flags
    attr_accessor :c, :z, :i, :d, :b, :v, :n
    def initialize
      @c = false
      @z = false
      @i = false
      @d = false
      @b = true
      @v = false
      @n = false
    end

    OPS = {
      z: ->x { x.zero? },
      v: ->x { x > 255 },
      n: ->x { x > 127 },
      c: ->x { x > 255   },
    }

    def update list, value
      cs = list.split('')
      cs.each do |c|
        nf = OPS[c.to_sym].call(value.to_i)
        instance_variable_set("@#{c}", nf)
      end
    end

    def inspect
      str = []
      %w{c z i d b v n}.each do |c|

        v = instance_variable_get("@#{c}")
        str.push(v ? c:' ')
      end

      str.unshift '<'
      str.push '>'
      str.join
    end
  end

  def step
    src = program.src[@pc]
    @inst = src
    src.call(self)
    self
  end

  def run
    while running == true do
      yield self
      step
    end
    yield self
  end

  def inspect
%Q{6502 pc=#{pc} run=#{running ? 't' : 'f'}
#{@inst && @inst.asm}
a=#{hexify a} x=#{hexify x} y=#{hexify y}
#{flags.inspect}
#{hexify(memory)}
-------}
  end
end

def hexify(v)
  case v
  when Hash
    h = {}
    v.each do |key, value|
      h[key.to_s(16)] = value.to_s(16)
    end
    return h
  when Integer
    return v.to_s(16).rjust(2, "0")
  when Nil
    return "00"
  else
    return v.to_i.to_s(16).rjust(2, "0")
  end
end

program = Program.load('example.s.rb')

cpu = CPU.new(program)
cpu.run do |c|
  p c
end
