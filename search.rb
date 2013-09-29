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
  attr_reader :tree
  attr_reader :index

  def initialize(size=1000, rebuild_data=false)
    puts 'Init...'
    @filenames={persons:"#{size}_persons", tree:"#{size}_tree", index:"#{size}_index"}
    @persons = DBM.open @filenames[:persons]
    if rebuild_data
      @persons.clear
    else
      @tree = load_attr_dump :tree
      @index = load_attr_dump :index
    end

    if @persons.empty?
      puts 'Persons are empty. Generating...'
      size.times {|id| @persons[id] = Marshal.dump [rand(BOUNDS[:age].last), rand(BOUNDS[:height].last), rand(BOUNDS[:weight].last), rand(BOUNDS[:salary].last*10)/10.0]}
      puts "#{@persons.size} elements generated"
    end
    unless @tree
      puts 'Tree are empty. Generating...'
      points = []
      @persons.each_pair do |id, person|
        person = Marshal.load person
        points << [person[FIELDS[:age]], person[FIELDS[:height]], person[FIELDS[:weight]], id.to_i]
      end
      @tree = KDTree.new points
      save_attr_dump :tree
    end
    unless @index
      puts 'Index are empty. Generating...'
      @index = SimpleIndex.new @persons
      save_attr_dump :index
    end
  end

  def load_attr_dump(name)
    File.open(@filenames[name], 'rb'){|f| Marshal::load(f)} if File.exist? @filenames[name]
  end
  def save_attr_dump(name)
    File.delete @filenames[name] if File.exist? @filenames[name]
    File.open(@filenames[name], 'wb') {|f| Marshal::dump(self.send(name), f)}
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
    c.delete_if{|field, range| BOUNDS[field]==range or not BOUNDS[field].cover? range.first or not BOUNDS[field].cover? range.last}
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
  # каждое условие производит выборку ids из своего индекса
  # перечесение итоговых массивов ids является результатом поиска
  def search_with_index(c)
    c = SampleSearch.prepare_conditions c
    return 'Conditions are empty' if c.size==0
    return self.search_bruteforce(c) if c.size==1 and c[:salary]
    salary_range = c.delete(:salary)
    initial_field = c.keys.first
    result_ids = @index.select_from(initial_field, c[initial_field])
    c.keys.delete initial_field
    c.each{|field, range| result_ids &= @index.select_from(field, range)}
    result_ids.delete_if{|id| not salary_range.include? Marshal.load(@persons[id.to_s])[FIELDS[:salary]]} if salary_range
    result_ids.sort
  end
  # поиск с использованием к-мерного бинарного дерева
  # три простых условия (возраст, рост, вес) задают отсечения областей при углублении в дерево
  # условие на зарплату (если оно есть) проверяется на полученных от дерева ids
  def search_with_tree(c)
    c = SampleSearch.prepare_conditions c
    return 'Conditions are empty' if c.size==0
    return self.search_bruteforce(c) if c.size==1 and c[:salary]
    result_ids = @tree.find(c[:age], c[:height], c[:weight])
    result_ids.delete_if{|i| not c[:salary].include? Marshal.load(@persons[i.to_s])[FIELDS[:salary]]} if c[:salary]
    result_ids.sort
  end
end





sample = SampleSearch.new ARGV[0].to_i, ARGV[1].to_i # size=1000, rebuild_data?=false
# puts sample.persons.first 10

conditions = [
  {},
  {age:40..60},
  {age:40..60, height:33..181},
  {age:40..60, salary:3000000.2..8000000.5},
  {age:50, height:33..181, weight:70..130},
  {age:10..90, height:33..181, weight:70..130, salary:3000000.2..8000000.5},
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
  # puts '    kd-tree: '+@res_kt[0..20].to_s
end
