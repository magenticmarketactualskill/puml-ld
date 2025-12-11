class ShaclRepository
  def initialize
    @shapes_dir = File.join(__dir__, '..', 'shapes')
  end
  
  def get_shape(diagram_type)
    shape_file = File.join(@shapes_dir, "#{diagram_type.downcase}_shape.ttl")
    
    return nil unless File.exist?(shape_file)
    
    File.read(shape_file)
  end
  
  def list_shapes
    Dir.glob(File.join(@shapes_dir, '*_shape.ttl')).map do |file|
      File.basename(file, '_shape.ttl').capitalize
    end
  end
end
