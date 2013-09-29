class KDTree
  attr_reader :root
  attr_reader :points

  def initialize(points)
    @dim = 3
    @root = KDNode.new(@dim).parse(points)
  end

  def add_node(point)
    @root.add(point)
  end

  def find(*range)
    @points = []
    # @root.print
    self.query(range, @root)
    @points
  end

  def query(range, node, l=1)
    a = node.axis
    median = node.location[a]
    self.query(range, node.left, l+1) if node.left && (range[a].nil? || range[a].begin<=median)
    self.query(range, node.right, l+1) if node.right && (range[a].nil? || median<=range[a].end)
    @points << node.location.last if (0..@dim-1).all?{|d| range[d] ? range[d].include?(node.location[d]) : true}
  end
end

class KDNode
  attr_reader :left, :right
  attr_reader :location
  attr_reader :axis

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

  def print(l=0)
    @left.print(l+1) if @left
    puts " "*l + @location.inspect
    @right.print(l+1) if @right
  end
end