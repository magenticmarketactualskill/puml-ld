class PumlParser
  class ParseError < StandardError; end
  
  DIAGRAM_TYPES = {
    'class' => 'Class',
    'sequence' => 'Sequence',
    'usecase' => 'UseCase',
    'entity' => 'ERD',
    'object' => 'Object',
    'activity' => 'Activity',
    'component' => 'Component',
    'state' => 'State',
    'deployment' => 'Deployment'
  }.freeze
  
  attr_reader :source, :diagram_type, :elements, :relationships
  
  def initialize(source)
    @source = source
    @diagram_type = nil
    @elements = []
    @relationships = []
  end
  
  def parse
    detect_diagram_type
    
    case @diagram_type
    when 'Class'
      parse_class_diagram
    when 'Sequence'
      parse_sequence_diagram
    when 'UseCase'
      parse_usecase_diagram
    when 'ERD'
      parse_erd_diagram
    else
      parse_generic_diagram
    end
    
    {
      diagram_type: @diagram_type,
      elements: @elements,
      relationships: @relationships
    }
  end
  
  private
  
  def detect_diagram_type
    # Check for explicit diagram type markers
    if @source =~ /@start(\w+)/
      type_key = $1.downcase
      @diagram_type = DIAGRAM_TYPES[type_key] || 'Generic'
    elsif @source =~ /@startuml/
      # Analyze content to infer type
      if @source =~ /\bclass\s+\w+/
        @diagram_type = 'Class'
      elsif @source =~ /\bactor\s+\w+|\busecase\s+\w+/
        @diagram_type = 'UseCase'
      elsif @source =~ /\bentity\s+\w+/
        @diagram_type = 'ERD'
      elsif @source =~ /-[->]+|<-[->]+/
        @diagram_type = 'Sequence'
      else
        @diagram_type = 'Generic'
      end
    else
      raise ParseError, "Not a valid PlantUML document (missing @startuml or @start* directive)"
    end
  end
  
  def parse_class_diagram
    lines = @source.lines.map(&:strip)
    
    lines.each do |line|
      next if line.empty? || line.start_with?('@', "'")
      
      # Parse class declarations
      if line =~ /^(abstract\s+)?class\s+(["\w]+)(?:\s+as\s+(\w+))?(?:\s*<<(.+)>>)?/
        is_abstract = !$1.nil?
        class_name = $2.gsub('"', '')
        alias_name = $3
        stereotype = $4
        
        element = {
          type: 'Class',
          name: class_name,
          alias: alias_name,
          abstract: is_abstract,
          stereotype: stereotype,
          attributes: [],
          methods: []
        }
        
        @elements << element
        
      # Parse interface declarations
      elsif line =~ /^interface\s+(["\w]+)(?:\s+as\s+(\w+))?/
        interface_name = $1.gsub('"', '')
        alias_name = $2
        
        element = {
          type: 'Interface',
          name: interface_name,
          alias: alias_name,
          methods: []
        }
        
        @elements << element
        
      # Parse enum declarations
      elsif line =~ /^enum\s+(["\w]+)(?:\s+as\s+(\w+))?/
        enum_name = $1.gsub('"', '')
        alias_name = $2
        
        element = {
          type: 'Enum',
          name: enum_name,
          alias: alias_name,
          values: []
        }
        
        @elements << element
        
      # Parse relationships
      elsif line =~ /(\w+)\s+(<?[.*o+#x}^-]+[|.>]+)\s+(\w+)(?:\s*:\s*(.+))?/
        source = $1
        relation_symbol = $2
        target = $3
        label = $4&.strip
        
        relationship = {
          type: parse_relationship_type(relation_symbol),
          source: source,
          target: target,
          label: label,
          source_cardinality: extract_cardinality(line, :source),
          target_cardinality: extract_cardinality(line, :target)
        }
        
        @relationships << relationship
        
      # Parse attributes and methods (simplified)
      elsif line =~ /^([+\-#~])?(\w+)\s*:\s*(\w+)/
        visibility = parse_visibility($1)
        name = $2
        type = $3
        
        # Add to last element if exists
        if @elements.any?
          @elements.last[:attributes] ||= []
          @elements.last[:attributes] << {
            name: name,
            datatype: type,
            visibility: visibility
          }
        end
        
      elsif line =~ /^([+\-#~])?(\w+)\s*\(([^)]*)\)(?:\s*:\s*(\w+))?/
        visibility = parse_visibility($1)
        name = $2
        params = $3
        return_type = $4
        
        # Add to last element if exists
        if @elements.any?
          @elements.last[:methods] ||= []
          @elements.last[:methods] << {
            name: name,
            parameters: params,
            return_type: return_type,
            visibility: visibility
          }
        end
      end
    end
  end
  
  def parse_sequence_diagram
    lines = @source.lines.map(&:strip)
    participants = []
    messages = []
    
    lines.each do |line|
      next if line.empty? || line.start_with?('@', "'")
      
      # Parse participant declarations
      if line =~ /^(participant|actor|boundary|control|entity|database)\s+(["\w]+)(?:\s+as\s+(\w+))?/
        participant_type = $1
        participant_name = $2.gsub('"', '')
        alias_name = $3
        
        participants << {
          type: participant_type.capitalize,
          name: participant_name,
          alias: alias_name
        }
        
      # Parse messages
      elsif line =~ /(\w+)\s*(<?-[->]+)\s*(\w+)(?:\s*:\s*(.+))?/
        source = $1
        arrow = $2
        target = $3
        message = $4&.strip
        
        messages << {
          type: 'Message',
          source: source,
          target: target,
          message: message,
          synchronous: !arrow.include?('--')
        }
      end
    end
    
    @elements = participants
    @relationships = messages
  end
  
  def parse_usecase_diagram
    lines = @source.lines.map(&:strip)
    
    lines.each do |line|
      next if line.empty? || line.start_with?('@', "'")
      
      # Parse actor declarations
      if line =~ /^actor\s+(["\w]+)(?:\s+as\s+(\w+))?/
        actor_name = $1.gsub('"', '')
        alias_name = $2
        
        @elements << {
          type: 'Actor',
          name: actor_name,
          alias: alias_name
        }
        
      # Parse use case declarations
      elsif line =~ /^usecase\s+(["\w]+)(?:\s+as\s+(\w+))?/
        usecase_name = $1.gsub('"', '')
        alias_name = $2
        
        @elements << {
          type: 'UseCase',
          name: usecase_name,
          alias: alias_name
        }
        
      # Parse relationships
      elsif line =~ /(\w+)\s+(<?\.\.+>?|<?-+>?)\s+(\w+)(?:\s*:\s*(.+))?/
        source = $1
        relation_symbol = $2
        target = $3
        label = $4&.strip
        
        @relationships << {
          type: relation_symbol.include?('.') ? 'Include' : 'Association',
          source: source,
          target: target,
          label: label
        }
      end
    end
  end
  
  def parse_erd_diagram
    lines = @source.lines.map(&:strip)
    
    lines.each do |line|
      next if line.empty? || line.start_with?('@', "'")
      
      # Parse entity declarations
      if line =~ /^entity\s+(["\w]+)(?:\s+as\s+(\w+))?/
        entity_name = $1.gsub('"', '')
        alias_name = $2
        
        @elements << {
          type: 'Entity',
          name: entity_name,
          alias: alias_name,
          attributes: []
        }
        
      # Parse relationships
      elsif line =~ /(\w+)\s+([|o}]?[|o]?--[|o]?[|o]?)\s+(\w+)(?:\s*:\s*(.+))?/
        source = $1
        relation_symbol = $2
        target = $3
        label = $4&.strip
        
        @relationships << {
          type: 'Relationship',
          source: source,
          target: target,
          label: label,
          source_cardinality: parse_erd_cardinality(relation_symbol, :left),
          target_cardinality: parse_erd_cardinality(relation_symbol, :right)
        }
      end
    end
  end
  
  def parse_generic_diagram
    # Fallback parser for unsupported diagram types
    lines = @source.lines.map(&:strip)
    
    lines.each do |line|
      next if line.empty? || line.start_with?('@', "'")
      
      # Extract any identifiable elements
      if line =~ /^(\w+)\s+(["\w]+)/
        element_type = $1
        element_name = $2.gsub('"', '')
        
        @elements << {
          type: element_type.capitalize,
          name: element_name
        }
      end
    end
  end
  
  def parse_relationship_type(symbol)
    case symbol
    when /<\|--/, /--\|>/
      'Extension'
    when /<\|\.\./, /\.\.\|>/
      'Implementation'
    when /\*--/, /--\*/
      'Composition'
    when /o--/, /--o/
      'Aggregation'
    when /-->/, /<--/
      'Dependency'
    when /\.\.>/, /<\.\./
      'Dependency'
    else
      'Association'
    end
  end
  
  def parse_visibility(symbol)
    case symbol
    when '+'
      'public'
    when '-'
      'private'
    when '#'
      'protected'
    when '~'
      'package'
    else
      'public'
    end
  end
  
  def extract_cardinality(line, position)
    # Extract cardinality from quotes in relationship line
    matches = line.scan(/"([^"]+)"/)
    return nil if matches.empty?
    
    position == :source ? matches[0]&.first : matches[1]&.first
  end
  
  def parse_erd_cardinality(symbol, side)
    chars = side == :left ? symbol[0..1] : symbol[-2..-1]
    
    case chars
    when /\|\|/
      '1'
    when /\|o/, /o\|/
      '0..1'
    when /\}o/, /o\{/
      '0..*'
    when /\}\|/, /\|\{/
      '1..*'
    else
      '*'
    end
  end
end
