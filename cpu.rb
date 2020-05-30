class Program
  attr_accessor :ac, :labels, :src, :filename

  def self.load filename
    prog = new
    prog.instance_eval(File.read(filename), filename)
    prog.filename = filename
    prog
  end

  def self.opcode name, &block
    define_method(name) do
      outerBlock = lambda do |prog|
        line = block
        prog.src.append(line)
        prog.ac = ac + 1
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

  opcode :jmp_a do |cpu|
    cpu.pc = labels[label]
  end

  opcode :inx do |cpu|
    cpu.x = cpu.x + 1
    if cpu.x > 0xff
      cpu.x = 0
    end
    cpu.pc += 1
  end


  opcode :brk do |cpu|
    cpu.running = false
  end

  def lda_i val
    line = lambda do |cpu|
      cpu.a = val
      cpu.pc += 1
    end
    @src.append(line)
    self.ac = ac + 1
  end

  def sta_a loc
    line = lambda do |cpu|
      cpu.memory[loc] = cpu.a
      cpu.pc += 1
    end
    @src.append(line)
    self.ac = ac + 1
  end

  def tax
    line = lambda do |cpu|
      cpu.x = cpu.a
      cpu.pc += 1
    end
    @src.append(line)
    self.ac = ac + 1
  end
end

class CPU
  attr_accessor :pc, :a, :x, :y, :program, :running, :memory

  def initialize(program)
    @pc = 0
    @program = program
    @running = true
    @memory = []
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
end

p = Program.load('example.s.rb')

cpu = CPU.new(p)
cpu.run do |c|
  p c
end
