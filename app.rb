require 'sinatra'
require 'json'
require 'rdf'
require 'json/ld'
require_relative 'lib/puml_parser'
require_relative 'lib/jsonld_converter'
require_relative 'lib/shacl_repository'

# Configure Sinatra
set :port, 4567
set :bind, '0.0.0.0'

# Initialize SHACL repository
SHACL_REPO = ShaclRepository.new

# Root endpoint
get '/' do
  content_type :json
  {
    name: 'puml-ld',
    version: '1.0.0',
    description: 'Converts PlantUML documents to JSON-LD format',
    endpoints: {
      shacl: {
        method: 'GET',
        path: '/shacl',
        description: 'Retrieve SHACL shape definitions by diagram type',
        parameters: {
          name: 'Diagram type (ERD, Sequence, Class, UseCase, etc.)'
        },
        example: '/shacl?name=Class'
      },
      convert: {
        method: 'PUT',
        path: '/convert',
        description: 'Convert PlantUML document to JSON-LD',
        headers: {
          'Context': 'JSON-LD context URL or inline JSON',
          'Id': 'Base IRI for generated resources'
        },
        body: 'PlantUML source code (text/plain)',
        example: 'PUT /convert with PlantUML in body'
      }
    }
  }.to_json
end

# SHACL endpoint - retrieve shape definitions
get '/shacl' do
  shape_name = params['name']
  
  unless shape_name
    status 400
    content_type :json
    return { error: 'Missing required parameter: name' }.to_json
  end
  
  shape = SHACL_REPO.get_shape(shape_name)
  
  unless shape
    status 404
    content_type :json
    return { error: "SHACL shape not found for diagram type: #{shape_name}" }.to_json
  end
  
  # Return shape in Turtle format by default
  content_type 'text/turtle'
  shape
end

# Convert endpoint - convert PlantUML to JSON-LD
put '/convert' do
  # Get headers
  context_header = request.env['HTTP_CONTEXT']
  id_header = request.env['HTTP_ID']
  
  # Validate required headers
  unless context_header && id_header
    status 400
    content_type :json
    return {
      error: 'Missing required headers',
      required: {
        'Context': 'JSON-LD context URL or inline JSON',
        'Id': 'Base IRI for generated resources'
      }
    }.to_json
  end
  
  # Read PlantUML source from request body
  puml_source = env['rack.input'].read
  
  if puml_source.nil? || puml_source.empty?
    status 400
    content_type :json
    return { error: 'Request body is empty. PlantUML source required.' }.to_json
  end
  
  begin
    # Parse context header (could be URL or inline JSON)
    context = if context_header.start_with?('http://', 'https://')
                context_header
              else
                JSON.parse(context_header)
              end
  rescue JSON::ParserError => e
    status 400
    content_type :json
    return { error: "Invalid Context header: #{e.message}" }.to_json
  end
  
  begin
    # Parse PlantUML source
    parser = PumlParser.new(puml_source)
    diagram_data = parser.parse
    
    # Convert to JSON-LD
    converter = JsonldConverter.new(context, id_header)
    jsonld_output = converter.convert(diagram_data)
    
    # Return JSON-LD
    content_type 'application/ld+json'
    jsonld_output
    
  rescue PumlParser::ParseError => e
    status 422
    content_type :json
    { error: "PlantUML parsing failed: #{e.message}" }.to_json
    
  rescue JsonldConverter::ConversionError => e
    status 500
    content_type :json
    { error: "JSON-LD conversion failed: #{e.message}" }.to_json
    
  rescue StandardError => e
    status 500
    content_type :json
    { error: "Internal server error: #{e.message}" }.to_json
  end
end

# Health check endpoint
get '/health' do
  content_type :json
  { status: 'ok', timestamp: Time.now.iso8601 }.to_json
end
