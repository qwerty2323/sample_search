# encoding: utf-8
require 'dbm'
require 'benchmark'
require_relative 'simple_index.rb'
require_relative 'kd_tree.rb'

FIELDS = {age:0, height:1, weight:2, salary:3}
BOUNDS = {age:0..100, height:0..200, weight:0..200, salary:0..10000000.0}

class SampleSearch
  attr_reader :filenames
  attr_reader :persons
  attr_reader :index
  attr_reader :tree

  def initialize(size=1000)
    puts 'Init...'
    @filenames={persons:"#{size}", index:"#{size}.index", tree:"#{size}.tree", tree4:"#{size}.tree4"}
    @persons = DBM.open @filenames[:persons]
    puts "#{@persons.size} persons found" if @persons.size>0
    @index = load_attr_dump :index
    puts "index found" if @index
    @tree = load_attr_dump :tree
    puts "tree found" if @tree

    if @persons.empty?
      puts 'Persons are empty. Generating...'
      size.times{|id| @persons[id] = Marshal.dump [rand(BOUNDS[:age].last), rand(BOUNDS[:height].last), rand(BOUNDS[:weight].last), rand(BOUNDS[:salary].last*10)/10.0]}
      puts "#{@persons.size} elements generated"
    end
    unless @index
      puts 'Index are empty. Generating...'
      points = {}
      @persons.each_pair do |id, person|
        person = Marshal.load person
        points[id] = [person[FIELDS[:age]], person[FIELDS[:height]], person[FIELDS[:weight]]]
      end
      @index = SimpleIndex.new points
      save_attr_dump :index
    end
    unless @tree
      puts 'Tree are empty. Generating...'
      points = []
      @persons.each_pair do |id, person|
        person = Marshal.load person
        points << [person[FIELDS[:age]], person[FIELDS[:height]], person[FIELDS[:weight]], person[FIELDS[:salary]], id.to_i]
      end
      @tree = KDTree.new points, 4
      save_attr_dump :tree
    end
  end

  def load_attr_dump(name)
    File.open(@filenames[name], 'rb'){|f| Marshal::load(f)} if File.exist? @filenames[name]
  end
  def save_attr_dump(name)
    File.delete @filenames[name] if File.exist? @filenames[name]
    File.open(@filenames[name], 'wb'){|f| Marshal::dump(self.send(name), f)}
  end
  # проверки и отсечения условий
  def self.prepare_conditions(c)
    return {} unless c
    c.delete_if{|field, range| not FIELDS.keys.include? field}
    c.each do |field, range|
      next if range.kind_of? Range
      c[field] = Range.new(range.first, range.last) and next if range.kind_of? Array
      c[field] = Range.new(range, range) and next if range.kind_of? Numeric
      c.delete(field)
    end
    c.delete_if{|field, range| range.first<=BOUNDS[field].first and BOUNDS[field].last<=range.last}
    c
  end

  # поиск простым перебором всех данных
  # производит сравнение каждого объекта с заданным набором условий
  # нужен для эталонного сравнения c "медленным" вариантом
  def search_bruteforce(c)
    c = SampleSearch.prepare_conditions c
    return 'Conditions are empty' if c.size==0
    result_ids = []
    @persons.each_pair do |id, person|
      person = Marshal.load person
      result_ids<<id.to_i if c.all?{|field, range| range.include? person[FIELDS[field]]}
    end
    result_ids.sort
  end
  # поиск по предварительно сгенерированным индексам для каждого значения каждого поля
  # каждое условие (кроме зарплаты) производит выборку ids из своего индекса
  # перечесение итоговых массивов ids является результатом поиска
  # условие на зарплату (если оно есть) проверяется на полученных от пересечения ids
  def search_with_index(c)
    c = SampleSearch.prepare_conditions c
    return 'Conditions are empty' if c.size==0
    return self.search_bruteforce(c) if c.size==1 and c[:salary]
    salary_range = c.delete(:salary)
    initial_field = c.keys.first
    result_ids = @index.select_from(FIELDS[initial_field], c[initial_field])
    c.delete initial_field
    c.each{|field, range| result_ids &= @index.select_from(FIELDS[field], range)}
    result_ids.delete_if{|id| not salary_range.include? Marshal.load(@persons[id.to_s])[FIELDS[:salary]]} if salary_range
    result_ids.sort
  end
  # поиск с использованием к-мерного бинарного дерева
  # претендент на звание "самого быстрого" алгоритма для k-мерных областей данных с равномерным распределением
  # условия задают отсечения областей при углублении в дерево
  def search_with_tree(c)
    c = SampleSearch.prepare_conditions c
    return 'Conditions are empty' if c.size==0
    result_ids = @tree.find c[:age], c[:height], c[:weight], c[:salary]
    result_ids.sort
  end
end





sample = SampleSearch.new ARGV[0].to_i
# puts sample.persons.first 10

conditions = [
  {test:true}, # проверка неверного поля и пустого набора условий
  {age:40..60}, # простой поиск по одному условию
  {age:50, height:33..181}, # посложнее
  {age:10..90, salary:4000000.2..7000000.5}, # подмешиваем зарплату
  {age:40..60, height:33..181, weight:70..130}, # три простых диапазона
  {age:20..80, height:33..181, weight:70..130, salary:4000000.2..7000000.5}, # все возможные условия
]
conditions.each do |c|
  puts "\n#{c}"
  Benchmark.bm do |x|
    x.report{@res_bf = sample.search_bruteforce(c.dup)}
    x.report{@res_si = sample.search_with_index(c.dup)}
    x.report{@res_kt = sample.search_with_tree(c.dup)}
  end
  # puts ' bruteforce: '+@res_bf[0..20].to_s
  # puts 'simpleindex: '+@res_si[0..20].to_s
  # puts '    4d-tree: '+@res_kt[0..20].to_s
end
