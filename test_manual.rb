#!/usr/bin/env ruby

require_relative 'lib/puml_parser'
require_relative 'lib/jsonld_converter'

# Test PlantUML source
puml_source = <<~PUML
  @startuml
  class Person {
    -name: String
    -age: Integer
    +getName(): String
  }
  
  class Company {
    -name: String
  }
  
  Person "1..*" -- "1" Company : works for
  @enduml
PUML

puts "Testing PlantUML Parser..."
parser = PumlParser.new(puml_source)
diagram_data = parser.parse

puts "Diagram Type: #{diagram_data[:diagram_type]}"
puts "Elements: #{diagram_data[:elements].size}"
puts "Relationships: #{diagram_data[:relationships].size}"
puts

puts "Testing JSON-LD Converter..."
context = { "@vocab" => "http://example.org/uml#", "name" => "rdfs:label" }
base_iri = "http://example.org/diagrams/test"

converter = JsonldConverter.new(context, base_iri)
jsonld_output = converter.convert(diagram_data)

puts jsonld_output
