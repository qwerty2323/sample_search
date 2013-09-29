class SimpleIndex
  attr_reader :index

  def initialize(persons)
    @index = {} and FIELDS.keys.each{|n| @index[n]={}}
    persons.each_pair do |id, person|
      person = Marshal.load person
      person.each_with_index do |v, k|
        @index[FIELDS.invert[k]][v] ||= []
        @index[FIELDS.invert[k]][v] << id.to_i
      end
    end
    @index.keys.each {|field| @index[field] = Hash[@index[field].sort_by{|k, v| k}]}
  end

  def select_from(field, range=nil)
    return [] unless field
    return @index[field].keys unless range
    result_ids = []
    @index[field].each{|v, ids| result_ids+=ids if range.include? v}
    result_ids
  rescue
    []
  end
end