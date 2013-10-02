class SimpleIndex
  attr_reader :index

  def initialize(points)
    @index = [{}, {}, {}]
    points.each{|id, point| point.each_with_index{|v, i| (@index[i][v] ||= []) << id.to_i}}
    @index.map{|field| field = Hash[field.sort_by{|k, v| k}]}
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
