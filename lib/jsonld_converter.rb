require 'json'
require 'rdf'
require 'json/ld'

class JsonldConverter
  class ConversionError < StandardError; end
  
  attr_reader :context, :base_iri
  
  def initialize(context, base_iri)
    @context = context
    @base_iri = base_iri.end_with?('#') ? base_iri : "#{base_iri}#"
  end
  
  def convert(diagram_data)
    diagram_type = diagram_data[:diagram_type]
    elements = diagram_data[:elements]
    relationships = diagram_data[:relationships]
    
    # Build JSON-LD document
    jsonld = {
      '@context' => @context,
      '@graph' => []
    }
    
    # Convert elements
    elements.each_with_index do |element, index|
      jsonld_element = convert_element(element, index)
      jsonld['@graph'] << jsonld_element if jsonld_element
    end
    
    # Convert relationships
    relationships.each_with_index do |relationship, index|
      jsonld_relationship = convert_relationship(relationship, index)
      jsonld['@graph'] << jsonld_relationship if jsonld_relationship
    end
    
    # Add diagram metadata
    jsonld['@graph'].unshift({
      '@id' => @base_iri.chomp('#'),
      '@type' => "#{diagram_type}Diagram",
      'elementCount' => elements.size,
      'relationshipCount' => relationships.size
    })
    
    JSON.pretty_generate(jsonld)
    
  rescue StandardError => e
    raise ConversionError, "Failed to convert to JSON-LD: #{e.message}"
  end
  
  private
  
  def convert_element(element, index)
    element_type = element[:type]
    element_name = element[:name] || element[:alias] || "element_#{index}"
    
    # Create base JSON-LD node
    node = {
      '@id' => generate_iri(element_name),
      '@type' => element_type
    }
    
    # Add common properties
    node['name'] = element_name if element[:name]
    node['alias'] = element[:alias] if element[:alias]
    node['abstract'] = element[:abstract] if element.key?(:abstract)
    node['stereotype'] = element[:stereotype] if element[:stereotype]
    
    # Add type-specific properties
    case element_type
    when 'Class', 'Interface', 'Entity'
      node['attributes'] = element[:attributes].map { |attr| convert_attribute(attr) } if element[:attributes]&.any?
      node['methods'] = element[:methods].map { |method| convert_method(method) } if element[:methods]&.any?
      
    when 'Enum'
      node['values'] = element[:values] if element[:values]&.any?
      
    when 'Actor', 'UseCase'
      # Use case specific properties already covered by common properties
      
    when /Participant|Actor|Boundary|Control|Database/
      # Sequence diagram participants
      node['participantType'] = element_type
    end
    
    node
  end
  
  def convert_attribute(attribute)
    attr_node = {
      '@type' => 'Attribute',
      'name' => attribute[:name]
    }
    
    attr_node['datatype'] = attribute[:datatype] if attribute[:datatype]
    attr_node['visibility'] = attribute[:visibility] if attribute[:visibility]
    attr_node['defaultValue'] = attribute[:default_value] if attribute[:default_value]
    
    attr_node
  end
  
  def convert_method(method)
    method_node = {
      '@type' => 'Method',
      'name' => method[:name]
    }
    
    method_node['parameters'] = method[:parameters] if method[:parameters]
    method_node['returnType'] = method[:return_type] if method[:return_type]
    method_node['visibility'] = method[:visibility] if method[:visibility]
    method_node['abstract'] = method[:abstract] if method.key?(:abstract)
    method_node['static'] = method[:static] if method.key?(:static)
    
    method_node
  end
  
  def convert_relationship(relationship, index)
    rel_type = relationship[:type]
    source = relationship[:source]
    target = relationship[:target]
    
    # Create relationship node
    node = {
      '@id' => generate_iri("relationship_#{index}"),
      '@type' => rel_type,
      'source' => generate_iri(source),
      'target' => generate_iri(target)
    }
    
    # Add optional properties
    node['label'] = relationship[:label] if relationship[:label]
    node['message'] = relationship[:message] if relationship[:message]
    node['sourceCardinality'] = relationship[:source_cardinality] if relationship[:source_cardinality]
    node['targetCardinality'] = relationship[:target_cardinality] if relationship[:target_cardinality]
    node['synchronous'] = relationship[:synchronous] if relationship.key?(:synchronous)
    
    node
  end
  
  def generate_iri(name)
    # Sanitize name for use in IRI
    sanitized = name.gsub(/[^a-zA-Z0-9_]/, '_')
    "#{@base_iri}#{sanitized}"
  end
end
