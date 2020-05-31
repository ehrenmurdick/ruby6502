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

  opcode :jmp_a do |cpu, prog, label|
    cpu.pc = prog.labels[label]
  end

  opcode :inx do |cpu|
    cpu.x += 1
    if cpu.x > 0xff
      cpu.x = 0
    end
  end

  opcode :brk do |cpu|
    cpu.running = false
  end

  opcode :lda_i do |cpu, _, val|
    cpu.a = val
  end

  opcode :sta_a do |cpu, _, val|
    cpu.memory[val] = cpu.a
  end

  opcode :tax do |cpu|
    cpu.x = cpu.a
  end
end

class CPU
  attr_accessor :pc, :a, :x, :y, :program, :running, :memory

  def initialize(program)
    @pc = 0
    @program = program
    @running = true
    @memory = []
    @a = 0
    @x = 0
    @y = 0
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

program = Program.load('example.s.rb')

cpu = CPU.new(program)
cpu.run do |c|
  p c
end
