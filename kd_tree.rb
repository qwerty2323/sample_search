class KDTree
  attr_reader :root,
              :points

  def initialize(points, dim=3)
    @dim = dim
    @root = KDNode.new(@dim).parse(points)
  end

  def add_node(point)
    @root.add(point)
  end

  def find(*range)
    @points = []
    # @root.print
    self.query(range, @root){|p| @points<<p}
    @points
  end

  def query(range, node)
    return unless node
    a = node.axis
    median = node.location[a]
    self.query(range, node.left){|p| yield p} if range[a].nil? || range[a].begin<=median
    self.query(range, node.right){|p| yield p} if range[a].nil? || median<=range[a].end
    yield node.location.last if node.match? range
  end

  def print
    @root.print
  end
end

class KDNode
  attr_reader :left,
              :right,
              :location,
              :axis

  def initialize(dim, location=nil, left=nil, right=nil)
    @dim = dim
    @location = location
    @left = left
    @right = right
  end

  def parse(points, depth=0)
    @axis = depth % @dim
    points = points.sort_by{|point| point[@axis]}
    half = points.length/2
    @location = points[half]
    @left = KDNode.new(@dim).parse(points[0..half-1], depth+1) unless half < 1
    @right = KDNode.new(@dim).parse(points[half+1..-1], depth+1) unless half+1 >= points.length
    self
  end

  def add(point)
    if @location[@axis] < point[@axis]
      @left ? @left.add(point) : @left = KDNode.new(point)
    else
      @right ? @right.add(point) : @right = KDNode.new(point)
    end
  end

  def match?(range)
    (0..@dim-1).all?{|d| range[d].nil? or range[d].cover?(self.location[d])}
  end

  def print(l=0)
    @left.print(l+1) if @left
    puts " "*l + @location.inspect
    @right.print(l+1) if @right
  end
end