class Program
  attr_accessor :ac, :labels, :src, :filename

  def self.load filename
    prog = new
    prog.instance_eval(File.read(filename), filename)
    prog.filename = filename
    prog
  end

  def self.opcode name, &block
    define_method(name) do |*args|
      outerBlock = lambda do |prog|
        line = lambda do |cpu|
          cpu.pc += 1
          block.call(cpu, self, *args)
        end
        prog.src.append(line)
        prog.ac += 1
      end
      outerBlock.call(self)
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

  opcode :adc_im do |cpu, _, val|
    cpu.flags.update 'nvzc', (cpu.a + val)
    cpu.a += val
  end

  opcode :jmp_ab do |cpu, prog, label|
    cpu.pc = prog.labels[label]
  end

  opcode :ina do |cpu|
    cpu.a += 1
  end
  opcode :inx do |cpu|
    cpu.x += 1
  end

  opcode :brk do |cpu|
    cpu.running = false
  end

  opcode :lda_im do |cpu, _, val|
    cpu.a = val
    cpu.flags.update 'z', val
  end
  opcode :lda_ab do |cpu, _, val|
    cpu.a = cpu.memory[val]
    cpu.flags.update 'z', val
  end
  opcode :lda_z do |cpu, _, val|
    cpu.a = cpu.memory[val]
    cpu.flags.update 'z', val
  end
  opcode :lda_zx do |cpu, _, val|
    cpu.a = cpu.memory[val]
    cpu.flags.update 'z', val
  end


  opcode :sta_ab do |cpu, _, val|
    cpu.memory[val] = cpu.a
  end

  opcode :tax do |cpu|
    cpu.x = cpu.a
    cpu.flags.update 'nz', val
  end
end

class CPU
  attr_accessor :pc, :program, :running, :memory, :flags

  def self.register *names
    names.each do |name|
      define_method(name) do
        instance_variable_get("@#{name}")
      end

      define_method(:"#{name}=") do |v|
        if v > 255
          v -= 256
        end
        instance_variable_set("@#{name}", v)
      end
    end
  end
  register :a, :x, :y

  def initialize(program)
    @pc = 0
    @program = program
    @running = true
    @memory = []
    @a = 0
    @x = 0
    @y = 0
    @flags = Flags.new
  end

  class Flags
    attr_accessor :c, :z, :i, :d, :b, :o, :n
    def initialize
      @c = false
      @z = false
      @i = false
      @d = false
      @b = false
      @o = false
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
        nf = OPS[c.to_sym].call(value)
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
    program.src[@pc].call(self)
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
    "6502 pc=#{pc} run=#{running ? 't' : 'f'} fs=#{flags.inspect} \n a=#{a} x=#{x} y=#{} \n-------"
  end
end

program = Program.load('example.s.rb')

cpu = CPU.new(program)
cpu.run do |c|
  p c
end
